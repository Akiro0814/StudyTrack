package com.repea.studytrack.utils

import android.content.Context
import android.database.Cursor
import android.net.Uri
import androidx.room.withTransaction
import com.repea.studytrack.data.local.AppDatabase
import com.repea.studytrack.repository.AppThemeStyle
import com.repea.studytrack.repository.UserPreferencesRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import javax.inject.Inject
import javax.inject.Singleton

/** Full v1 Android -> iOS export. Fails on missing resources or lossy normalization. */
@Singleton
class BackupExporterV1 @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val database: AppDatabase,
    private val preferences: UserPreferencesRepository
) {
    private val mutex = Mutex()

    suspend fun export(destination: Uri, sourceZone: String) = withContext(Dispatchers.IO) {
        mutex.withLock {
            ZoneId.of(sourceZone) // Explicit user-confirmed source timezone, never infer from timestamps.
            val identity = context.getSharedPreferences("backup_v1_identity", Context.MODE_PRIVATE)
            val editor = identity.edit()
            fun stable(key: String): String = identity.getString(key, null) ?: UUID.randomUUID().toString().also {
                editor.putString(key, it)
            }
            val dataset = stable("dataset")
            val now = Instant.now().toString()
            val migratedAt = identity.getString("migration_timestamp", null) ?: now.also {
                editor.putString("migration_timestamp", it)
            }
            val canonical = mutableMapOf<String, String>()
            val mappings = JSONArray()
            fun id(type: String, legacy: String): String = canonical.getOrPut("$type:$legacy") {
                stable("$type:$legacy").also { uuid ->
                    mappings.put(JSONObject().put("sourceDatasetID", dataset).put("entityType", type)
                        .put("legacyID", legacy).put("canonicalID", uuid))
                }
            }
            val users = JSONArray(); val semesters = JSONArray(); val subjects = JSONArray(); val exams = JSONArray()
            val assets = JSONArray(); val resources = linkedMapOf<String, ByteArray>()
            val assetByHash = mutableMapOf<String, String>()
            fun asset(uriText: String?): String? {
                if (uriText.isNullOrBlank()) return null
                val uri = Uri.parse(uriText)
                val bytes = context.contentResolver.openInputStream(uri)?.use { input ->
                    val output = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(16 * 1024)
                    while (true) {
                        val count = input.read(buffer); if (count < 0) break
                        require(output.size() + count <= 50 * 1024 * 1024) { "单个资源超过 50MB，请先调整资源" }
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: error("无法读取壁纸或附件，请重新选择资源后再备份")
                val hash = sha(bytes)
                return assetByHash.getOrPut(hash) {
                    val uuid = UUID.nameUUIDFromBytes("studytrack-asset:$hash".toByteArray()).toString()
                    val mime = context.contentResolver.getType(uri) ?: "application/octet-stream"
                    val extension = when (mime) { "image/jpeg" -> "jpg"; "image/png" -> "png"; else -> "bin" }
                    val path = "assets/$hash.$extension"
                    require(resources.values.sumOf { it.size.toLong() } + bytes.size <= 400L * 1024 * 1024) { "资源总量超过备份限制" }
                    resources[path] = bytes
                    assets.put(JSONObject().put("id", uuid).put("relativePath", path).put("mimeType", mime)
                        .put("sha256", hash).put("byteCount", bytes.size))
                    uuid
                }
            }
            val prefs = preferences.preferences.first()
            val semesterUsers = mutableMapOf<Int, Int>()
            val subjectScopes = mutableMapOf<Int, Pair<Int, Int>>()
            val subjectFullScores = mutableMapOf<Int, BigDecimal>()
            val knownUsers = mutableSetOf<Int>()
            val uniqueSemesterNames = mutableSetOf<Pair<Int, String>>()
            val uniqueSubjects = mutableSetOf<Triple<Int, Int, String>>()
            val uniqueExams = mutableSetOf<List<String>>()
            database.withTransaction {
                val db = database.openHelper.readableDatabase
                db.query("SELECT * FROM users ORDER BY createdAt,id").use { c ->
                    while (c.moveToNext()) {
                        val legacy = c.int("id"); knownUsers.add(legacy)
                        val name = BackupValues.normalized(c.string("name"))
                        require(name.isNotEmpty() && name.length <= 100) { "用户 $legacy 名称无效" }
                        val time = Instant.ofEpochMilli(c.long("createdAt")).toString()
                        users.put(JSONObject().put("id", id("user", "$legacy")).put("name", name).put("createdAt", time).put("updatedAt", time))
                    }
                }
                require(knownUsers.isNotEmpty()) { "请先完成首次引导" }
                db.query("SELECT * FROM semesters ORDER BY createdAt,id").use { c ->
                    while (c.moveToNext()) {
                        val legacy = c.int("id"); val user = c.int("userId"); val name = BackupValues.normalized(c.string("name"))
                        require(user in knownUsers && name.isNotEmpty() && name.length <= 100 && uniqueSemesterNames.add(user to name)) { "学期 $legacy 引用或名称冲突，请先修正" }
                        semesterUsers[legacy] = user
                        val time = Instant.ofEpochMilli(c.long("createdAt")).toString()
                        semesters.put(JSONObject().put("id", id("semester", "$legacy")).put("userID", id("user", "$user"))
                            .put("name", name).put("createdAt", time).put("updatedAt", time))
                    }
                }
                for (user in knownUsers) if (user !in semesterUsers.values) {
                    semesters.put(JSONObject().put("id", id("semester", "user-$user-default")).put("userID", id("user", "$user"))
                        .put("name", "默认学期").put("createdAt", migratedAt).put("updatedAt", migratedAt))
                }
                db.query("SELECT * FROM subjects ORDER BY id").use { c ->
                    while (c.moveToNext()) {
                        val legacy = c.int("id"); val user = c.int("userId"); val term = c.int("semesterId")
                        val name = BackupValues.normalized(c.string("name")); val full = BackupValues.score(c.double("fullScore"))
                        require(semesterUsers[term] == user && name.isNotEmpty() && name.length <= 100 && uniqueSubjects.add(Triple(user, term, name)) && BigDecimal(full).signum() > 0) { "科目 $legacy 归属、名称或满分冲突" }
                        subjectScopes[legacy] = user to term; subjectFullScores[legacy] = BigDecimal(full)
                        subjects.put(JSONObject().put("id", id("subject", "$legacy")).put("userID", id("user", "$user"))
                            .put("semesterID", id("semester", "$term")).put("name", name).put("fullScore", full)
                            .put("createdAt", migratedAt).put("updatedAt", migratedAt))
                    }
                }
                db.query("SELECT * FROM exam_records ORDER BY id").use { c ->
                    while (c.moveToNext()) {
                        val legacy = c.int("id"); val user = c.int("userId"); val term = c.int("semesterId"); val subject = c.int("subjectId")
                        val name = BackupValues.normalized(c.string("examName")); val score = BackupValues.score(c.double("score"))
                        val date = BackupValues.date(c.long("examDate"), sourceZone)
                        require(subjectScopes[subject] == (user to term) && BigDecimal(score) <= subjectFullScores.getValue(subject)) { "成绩 $legacy 归属或分数无效" }
                        require(name.length <= 100 && uniqueExams.add(listOf("$user", "$term", "$subject", name, date, score))) { "成绩 $legacy 在按日转换后重复，请先处理重复记录" }
                        val type = when (c.string("examType")) {
                            "月考", "MONTHLY", "monthly" -> "monthly"; "期中", "MIDTERM", "midterm" -> "midterm"
                            "期末", "FINAL", "final" -> "final"; "其他", "OTHER", "other" -> "other"
                            else -> error("成绩 $legacy 的考试类型未知，请先修正")
                        }
                        val reflection = c.optionalString("reflection")
                        require((reflection?.length ?: 0) <= 10000) { "成绩 $legacy 反思过长" }
                        val exam = JSONObject().put("id", id("exam", "$legacy")).put("userID", id("user", "$user"))
                            .put("semesterID", id("semester", "$term")).put("subjectID", id("subject", "$subject"))
                            .put("name", name).put("date", date).put("score", score).put("type", type)
                            .put("reflection", reflection ?: JSONObject.NULL).put("attachmentID", asset(c.optionalString("imageUri")) ?: JSONObject.NULL)
                            .put("createdAt", migratedAt).put("updatedAt", migratedAt)
                        for ((column, key) in listOf("classRank" to "classRank", "gradeRank" to "gradeRank", "districtRank" to "districtRank")) {
                            val index = c.getColumnIndexOrThrow(column)
                            val rank = if (c.isNull(index)) null else c.getInt(index)
                            require(rank == null || rank > 0) { "成绩 $legacy 排名无效" }; exam.put(key, rank ?: JSONObject.NULL)
                        }
                        exams.put(exam)
                    }
                }
            }
            val wallpaper = asset(prefs.customWallpaperUri)
            val currentUser = if (prefs.currentUserId in knownUsers) prefs.currentUserId else knownUsers.first()
            val currentTerm = if (semesterUsers[prefs.currentSemesterId] == currentUser) id("semester", "${prefs.currentSemesterId}")
                else semesterUsers.entries.firstOrNull { it.value == currentUser }?.let { id("semester", "${it.key}") } ?: id("semester", "user-$currentUser-default")
            val android = JSONObject().put("version", 1).put("sourceTimeZone", sourceZone).put("migrationTimestamp", migratedAt)
                .put("glassBlurRadiusDp", prefs.glassBlurRadiusDp).put("glassRefractionHeightDp", prefs.glassRefractionHeightDp)
                .put("glassRefractionAmountDp", prefs.glassRefractionAmountDp).put("glassTintAlpha", prefs.glassTintAlpha)
                .put("glassBorderAlpha", prefs.glassBorderAlpha).put("glassVibrancyEnabled", prefs.glassVibrancyEnabled)
                .put("glassChromaticAberration", prefs.glassChromaticAberration)
            val settings = JSONObject().put("theme", if (prefs.themeStyle == AppThemeStyle.LIQUID_GLASS) "glass" else "simple")
                .put("accent", "blue").put("wallpaperAssetID", wallpaper ?: JSONObject.NULL).put("multiUserEnabled", prefs.multiUserEnabled)
                .put("currentUserID", id("user", "$currentUser")).put("currentSemesterID", currentTerm)
                .put("nameNormalizationVersion", 1).put("platformExtensions", JSONObject().put("android", android))
            val data = JSONObject().put("users", users).put("semesters", semesters).put("subjects", subjects)
                .put("examRecords", exams).put("assets", assets).put("legacyIDMap", mappings)
            // Persist identity before publishing so repeated exports reuse every canonical ID.
            check(editor.commit()) { "无法持久化迁移身份，备份未生成" }
            val files = linkedMapOf("data.json" to data.toString().toByteArray(Charsets.UTF_8), "preferences.json" to settings.toString().toByteArray(Charsets.UTF_8))
            files.putAll(resources)
            val fileList = JSONArray()
            files.forEach { (path, bytes) -> fileList.put(JSONObject().put("path", path).put("byteCount", bytes.size).put("sha256", sha(bytes))) }
            val counts = JSONObject().put("users", users.length()).put("semesters", semesters.length()).put("subjects", subjects.length())
                .put("examRecords", exams.length()).put("assets", assets.length()).put("legacyIDMap", mappings.length())
            val manifest = JSONObject().put("format", "studytrack-backup").put("formatVersion", 1).put("backupID", UUID.randomUUID().toString())
                .put("sourceDatasetID", dataset).put("sourcePlatform", "android").put("sourceAppVersion", context.packageManager.getPackageInfo(context.packageName, 0).versionName)
                .put("exportedAt", now).put("recordCounts", counts).put("files", fileList)
            files["manifest.json"] = manifest.toString().toByteArray(Charsets.UTF_8)
            val temporary = File.createTempFile("studytrack-backup-", ".zip", context.cacheDir)
            try {
                ZipOutputStream(temporary.outputStream().buffered()).use { zip ->
                    files.forEach { (path, bytes) -> zip.putNextEntry(ZipEntry(path)); zip.write(bytes); zip.closeEntry() }
                }
                require(temporary.length() <= 100L * 1024 * 1024) { "压缩备份超过 100MB" }
                val output = context.contentResolver.openOutputStream(destination, "wt") ?: error("无法写入目标文件")
                output.use { target -> temporary.inputStream().use { it.copyTo(target) } }
            } finally { temporary.delete() }
        }
    }

    private fun sha(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    private fun Cursor.int(name: String) = getInt(getColumnIndexOrThrow(name))
    private fun Cursor.long(name: String) = getLong(getColumnIndexOrThrow(name))
    private fun Cursor.double(name: String) = getDouble(getColumnIndexOrThrow(name))
    private fun Cursor.string(name: String) = getString(getColumnIndexOrThrow(name))
    private fun Cursor.optionalString(name: String): String? = getColumnIndexOrThrow(name).let { if (isNull(it)) null else getString(it) }
}
