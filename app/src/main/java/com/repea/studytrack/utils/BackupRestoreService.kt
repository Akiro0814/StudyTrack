package com.repea.studytrack.utils

import android.content.Context
import android.net.Uri
import androidx.room.withTransaction
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

fun PlatformState.revisionToken(): String = BackupArchive.sha((users.toString() + semesters.toString() + allSubjects.toString() + allRecords.toString() + preferences.toString()).toByteArray())
data class BackupPreview(val archive: VerifiedArchive, val revision: String)

@Singleton
class BackupRestoreService @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val repository: PlatformRepository,
    private val exporter: BackupExporterV1
) {
    suspend fun inspect(uri: Uri): BackupPreview = withContext(Dispatchers.IO) {
        val revision = repository.snapshot().revisionToken()
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readLimited(100*1024*1024) } ?: error("无法读取备份")
        BackupPreview(BackupArchive.decode(bytes), revision)
    }
    suspend fun completePendingRestore() {
        val dao = repository.database.platformMetadataDao()
        dao.get("pendingIdentity")?.let { raw ->
            val map = JSONObject(raw); val editor = context.getSharedPreferences("backup_v1_identity", Context.MODE_PRIVATE).edit().clear()
            for (key in map.keys()) editor.putString(key, map.getString(key))
            check(editor.commit()) { "无法恢复备份身份，请重新打开应用" }
        }
        dao.get("pendingPreferences")?.let { repository.preferences.replace(PreferenceStateCodec.decode(it)) }
        repository.database.withTransaction { dao.remove("pendingIdentity"); dao.remove("pendingPreferences") }
    }
    suspend fun restore(preview: BackupPreview) = withContext(Dispatchers.IO) {
        repository.mutationMutex.withLock {
            val old = repository.snapshot()
            require(old.revisionToken() == preview.revision) { "预览后数据已改变，请重新选择备份并检查" }
            // Keep an immutable rollback before any destructive write.
            val recovery = File(context.filesDir, "recovery").apply { mkdirs() }
            val rollback = File(recovery, "${UUID.randomUUID()}.studytrackbackup")
            if (old.users.isNotEmpty()) exporter.export(Uri.fromFile(rollback), ZoneId.systemDefault().id)
            val archive = preview.archive; val data = archive.data; val p = archive.preferences
            val assets = mutableMapOf<String, String>()
            for (asset in data.getJSONArray("assets").objects()) {
                val bytes = archive.files.getValue(asset.getString("relativePath"))
                val directory = File(context.filesDir, "assets").apply { mkdirs() }
                val extension = when (asset.getString("mimeType")) { "image/jpeg" -> "jpg"; "image/png" -> "png"; else -> "bin" }
                val file = File(directory, "${asset.getString("sha256")}-${asset.getString("id")}.$extension")
                if (file.exists()) require(BackupArchive.sha(file.readBytes()) == asset.getString("sha256")) { "恢复资源路径冲突" }
                else { val temporary = File(directory, "${UUID.randomUUID()}.tmp"); temporary.writeBytes(bytes); check(temporary.renameTo(file)) { "无法安装恢复资源" } }
                assets[asset.getString("id")] = Uri.fromFile(file).toString()
            }
            val userIDs = data.getJSONArray("users").objects().mapIndexed { index, item -> item.getString("id") to index + 1 }.toMap()
            val termIDs = data.getJSONArray("semesters").objects().mapIndexed { index, item -> item.getString("id") to index + 1 }.toMap()
            val subjectIDs = data.getJSONArray("subjects").objects().mapIndexed { index, item -> item.getString("id") to index + 1 }.toMap()
            val extension = p.optJSONObject("platformExtensions") ?: JSONObject()
            val ios = extension.optJSONObject("ios") ?: JSONObject(); val android = extension.optJSONObject("android") ?: JSONObject()
            val avatars = ios.optJSONObject("profileAvatars") ?: JSONObject()
            val mode = ios.optString("displayMode", "system").takeIf { it in listOf("system", "light", "dark") } ?: "system"
            val accent = p.optString("accent", "blue").let { if (Regex("#[0-9a-fA-F]{6}").matches(it)) it else when (it) { "green" -> "#1A8F70"; "orange" -> "#E0523D"; "purple" -> "#9C5CD1"; else -> "#4A66E8" } }
            val selected = UserPreferencesState(themeStyle = if (p.optString("theme") == "glass") AppThemeStyle.LIQUID_GLASS else AppThemeStyle.PURE_WHITE,
                customWallpaperUri = p.optionalString("wallpaperAssetID")?.let { assets[it] }, multiUserEnabled = p.optBoolean("multiUserEnabled"),
                currentUserId = userIDs.getValue(p.getString("currentUserID")), currentSemesterId = termIDs.getValue(p.getString("currentSemesterID")), firstLaunch = false,
                displayMode = mode, accentHex = accent, glassTintAlpha = ios.optString("glassTint", "0.08").toFloatOrNull()?.coerceIn(0f,0.5f) ?: 0.08f,
                glassBacking = ios.optString("glassBacking", "0.15").toFloatOrNull()?.coerceIn(0f,0.8f) ?: 0.15f,
                glassVariant = ios.optString("glassVariant", "regular"), glassBlurRadiusDp = android.optDouble("glassBlurRadiusDp", 12.0).toFloat().coerceIn(0f,48f),
                glassRefractionHeightDp = android.optDouble("glassRefractionHeightDp",15.0).toFloat().coerceIn(0f,48f), glassRefractionAmountDp = android.optDouble("glassRefractionAmountDp",20.0).toFloat().coerceIn(0f,96f),
                glassBorderAlpha = android.optDouble("glassBorderAlpha",0.2).toFloat().coerceIn(0f,0.6f), glassVibrancyEnabled = android.optBoolean("glassVibrancyEnabled",true), glassChromaticAberration = android.optBoolean("glassChromaticAberration",true)).sanitized()
            val identity = JSONObject().put("dataset", archive.manifest.getString("sourceDatasetID")).put("migration_timestamp", archive.manifest.getString("exportedAt"))
            val exchangeRows = JSONObject()
            for(item in data.getJSONArray("users").objects()) exchangeRows.put("user:${userIDs.getValue(item.getString("id"))}",item)
            for(item in data.getJSONArray("semesters").objects()) exchangeRows.put("semester:${termIDs.getValue(item.getString("id"))}",item)
            for(item in data.getJSONArray("subjects").objects()) exchangeRows.put("subject:${subjectIDs.getValue(item.getString("id"))}",item)
            for ((canonical, local) in userIDs) identity.put("user:$local", canonical)
            for ((canonical, local) in termIDs) identity.put("semester:$local", canonical)
            for ((canonical, local) in subjectIDs) identity.put("subject:$local", canonical)
            repository.database.withTransaction {
                val db = repository.database.openHelper.writableDatabase
                for (table in listOf("exam_records", "subjects", "semesters", "users", "platform_metadata")) db.execSQL("DELETE FROM $table")
                for (user in data.getJSONArray("users").objects()) repository.database.userDao().insertUser(UserProfile(id = userIDs.getValue(user.getString("id")), name = user.getString("name"), createdAt = Instant.parse(user.getString("createdAt")).toEpochMilli(), avatarUri = avatars.optionalString(user.getString("id"))?.let { assets[it] }))
                for (term in data.getJSONArray("semesters").objects()) {
                    val school = term.optJSONObject("schoolTerm")
                    repository.database.semesterDao().insertSemester(Semester(id = termIDs.getValue(term.getString("id")), name = term.getString("name"), userId = userIDs.getValue(term.getString("userID")), createdAt = Instant.parse(term.getString("createdAt")).toEpochMilli(), stage = school?.getString("stage"), schoolYear = school?.getInt("year"), half = school?.getInt("half")))
                }
                for (subject in data.getJSONArray("subjects").objects()) repository.database.subjectDao().insertSubject(Subject(id = subjectIDs.getValue(subject.getString("id")), name = subject.getString("name"), fullScore = subject.getString("fullScore").toDouble(), userId = userIDs.getValue(subject.getString("userID")), semesterId = termIDs.getValue(subject.getString("semesterID")), lineageId = subject.optionalString("lineageID")))
                for ((index, record) in data.getJSONArray("examRecords").objects().sortedWith(compareBy({ it.getString("date") },{ it.getString("createdAt") },{ it.getString("id") })).withIndex()) {
                    val localID = index + 1; identity.put("exam:$localID",record.getString("id"))
                    exchangeRows.put("exam:$localID",record)
                    fun rank(key: String) = if (record.isNull(key) || !record.has(key)) null else record.getInt(key)
                    repository.database.examRecordDao().insertRecord(ExamRecord(id = localID, subjectId = subjectIDs.getValue(record.getString("subjectID")), examName = record.getString("name"), examDate = RecordValidation.date(record.getString("date")), score = record.getString("score").toDouble(), examType = when(record.getString("type")) { "monthly" -> "月考"; "midterm" -> "期中"; "final" -> "期末"; else -> "其他" }, classRank = rank("classRank"), gradeRank = rank("gradeRank"), districtRank = rank("districtRank"), reflection = record.optionalString("reflection"), imageUri = record.optionalString("attachmentID")?.let { assets[it] }, userId = userIDs.getValue(record.getString("userID")), semesterId = termIDs.getValue(record.getString("semesterID")),dateOnly = record.getString("date")))
                }
                val dao = repository.database.platformMetadataDao()
                dao.put(PlatformMetadata("pendingPreferences", PreferenceStateCodec.encode(selected)))
                dao.put(PlatformMetadata("pendingIdentity", identity.toString()))
                dao.put(PlatformMetadata("preservedExtensions", extension.toString()))
                dao.put(PlatformMetadata("exchangeRows",exchangeRows.toString()))
                dao.put(PlatformMetadata("preservedLegacyIDMap",data.getJSONArray("legacyIDMap").toString()))
                val preservedAssets = org.json.JSONArray()
                for(asset in data.getJSONArray("assets").objects()) preservedAssets.put(JSONObject().put("asset",asset).put("uri",assets.getValue(asset.getString("id"))))
                dao.put(PlatformMetadata("preservedAssets",preservedAssets.toString()))
                if (rollback.exists()) dao.put(PlatformMetadata("latestRecovery", Uri.fromFile(rollback).toString()))
            }
            completePendingRestore()
        }
    }
    suspend fun latestRecovery(): Uri = repository.database.platformMetadataDao().get("latestRecovery")?.let(Uri::parse) ?: error("还没有本机恢复快照")
}

object PreferenceStateCodec {
    fun encode(p: UserPreferencesState): String = JSONObject().put("user",p.currentUserId).put("term",p.currentSemesterId).put("multi",p.multiUserEnabled)
        .put("theme",p.themeStyle.name).put("wallpaper",p.customWallpaperUri ?: JSONObject.NULL).put("mode",p.displayMode).put("accent",p.accentHex)
        .put("blur",p.glassBlurRadiusDp).put("height",p.glassRefractionHeightDp).put("amount",p.glassRefractionAmountDp).put("tint",p.glassTintAlpha)
        .put("border",p.glassBorderAlpha).put("vibrancy",p.glassVibrancyEnabled).put("chromatic",p.glassChromaticAberration).put("backing",p.glassBacking).put("variant",p.glassVariant).toString()
    fun decode(raw: String): UserPreferencesState {
        val o = JSONObject(raw)
        return UserPreferencesState(currentUserId = o.getInt("user"), currentSemesterId = o.getInt("term"), multiUserEnabled = o.getBoolean("multi"), firstLaunch = false,
            themeStyle = AppThemeStyle.valueOf(o.getString("theme")), customWallpaperUri = o.optionalString("wallpaper"), displayMode = o.getString("mode"), accentHex = o.getString("accent"),
            glassBlurRadiusDp = o.getDouble("blur").toFloat(), glassRefractionHeightDp = o.getDouble("height").toFloat(), glassRefractionAmountDp = o.getDouble("amount").toFloat(),
            glassTintAlpha = o.getDouble("tint").toFloat(), glassBorderAlpha = o.getDouble("border").toFloat(), glassVibrancyEnabled = o.getBoolean("vibrancy"), glassChromaticAberration = o.getBoolean("chromatic"), glassBacking = o.getDouble("backing").toFloat(), glassVariant = o.getString("variant"))
    }
}
