package com.repea.studytrack.utils

import com.repea.studytrack.domain.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import java.util.zip.ZipInputStream

data class VerifiedArchive(val manifest: JSONObject, val data: JSONObject, val preferences: JSONObject, val files: Map<String, ByteArray>)

object BackupArchive {
    fun sha(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    private fun uuid(text: String) { require(UUID.fromString(text).toString() == text) { "备份 ID 格式无效" } }
    private fun path(text: String) { require(text.isNotBlank() && !text.startsWith('/') && '\\' !in text && ':' !in text && text.split('/').none { it == ".." || it == "." || it.isEmpty() }) { "备份包含不安全路径" } }
    fun decode(bytes: ByteArray): VerifiedArchive {
        require(bytes.size <= 100 * 1024 * 1024) { "备份超过 100MB" }
        val files = linkedMapOf<String, ByteArray>(); var total = 0L
        ZipInputStream(bytes.inputStream()).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                path(entry.name); require(!entry.isDirectory && files.size < 20000 && entry.name !in files) { "备份条目无效或重复" }
                val output = ByteArrayOutputStream(); val buffer = ByteArray(16384)
                while (true) { val count = zip.read(buffer); if (count < 0) break; total += count
                    require(total <= 500L*1024*1024 && output.size().toLong()+count <= 100L*1024*1024) { "解压后的备份超过大小限制" }; output.write(buffer, 0, count) }
                files[entry.name] = output.toByteArray(); zip.closeEntry()
            }
        }
        fun json(name: String, limit: Int): JSONObject { val data = files[name] ?: error("缺少 $name"); require(data.size <= limit) { "$name 超过大小限制" }; return JSONObject(data.toString(Charsets.UTF_8)) }
        val manifest = json("manifest.json", 4*1024*1024)
        require(manifest.getString("format") == "studytrack-backup" && manifest.getInt("formatVersion") == 1) { "不支持的备份格式" }
        uuid(manifest.getString("backupID")); uuid(manifest.getString("sourceDatasetID")); Instant.parse(manifest.getString("exportedAt"))
        val declared = manifest.getJSONArray("files").objects()
        require(declared.map { it.getString("path") }.toSet().size == declared.size && declared.map { it.getString("path") }.toSet() == files.keys - "manifest.json") { "备份清单不完整" }
        for (item in declared) {
            val data = files.getValue(item.getString("path"))
            require(item.getLong("byteCount") == data.size.toLong() && item.getString("sha256") == sha(data)) { "备份散列校验失败" }
        }
        val data = json("data.json", 100*1024*1024); val preferences = json("preferences.json", 1024*1024)
        val names = listOf("users", "semesters", "subjects", "examRecords", "assets", "legacyIDMap")
        val counts = manifest.getJSONObject("recordCounts")
        for (name in names) require(counts.getInt(name) == data.getJSONArray(name).length()) { "备份记录数量不符：$name" }
        val users = data.getJSONArray("users").objects(); val terms = data.getJSONArray("semesters").objects()
        val subjects = data.getJSONArray("subjects").objects(); val records = data.getJSONArray("examRecords").objects(); val assets = data.getJSONArray("assets").objects()
        require(users.isNotEmpty() && terms.isNotEmpty()) { "备份没有学习档案" }
        fun indexed(items: List<JSONObject>): Map<String, JSONObject> {
            val map = items.associateBy { it.getString("id").also(::uuid) }; require(map.size == items.size) { "重复 ID" }; return map
        }
        val u = indexed(users); val t = indexed(terms); val s = indexed(subjects); val e = indexed(records); val a = indexed(assets)
        for (item in users + terms + subjects) {
            require(RecordValidation.name(item.getString("name")) == item.getString("name")) { "名称未规范化" }
            Instant.parse(item.getString("createdAt")); Instant.parse(item.getString("updatedAt"))
        }
        val uniqueTerms = mutableSetOf<Pair<String, String>>()
        for (term in terms) {
            require(term.getString("userID") in u && uniqueTerms.add(term.getString("userID") to term.getString("name"))) { "学期归属或名称冲突" }
            term.optJSONObject("schoolTerm")?.let { SchoolTerm(SchoolStage.fromWire(it.getString("stage")) ?: error("无效学习阶段"), it.getInt("year"), it.getInt("half")) }
        }
        val uniqueSubjects = mutableSetOf<List<String>>()
        for (subject in subjects) {
            val term = t[subject.getString("semesterID")] ?: error("科目引用了不存在的学期")
            require(subject.getString("userID") == term.getString("userID") && uniqueSubjects.add(listOf(subject.getString("userID"), subject.getString("semesterID"), subject.getString("name")))) { "科目归属或名称冲突" }
            RecordValidation.fullScore(subject.getString("fullScore"))
            subject.optionalString("lineageID")?.let(::uuid)
        }
        val uniqueExams = mutableSetOf<List<String>>()
        for (record in records) {
            val subject = s[record.getString("subjectID")] ?: error("成绩引用了不存在的科目")
            require(record.getString("userID") == subject.getString("userID") && record.getString("semesterID") == subject.getString("semesterID")) { "成绩归属冲突" }
            RecordValidation.score(record.getString("score"), subject.getString("fullScore").toDouble())
            val date = LocalDate.parse(record.getString("date")); require(date.year in 1900..2100) { "成绩日期超出范围" }
            require(record.getString("type") in listOf("monthly", "midterm", "final", "other") && record.getString("name").length <= 100 && (record.optionalString("reflection")?.length ?: 0) <= 10000) { "考试字段无效" }
            for (key in listOf("classRank", "gradeRank", "districtRank")) if (!record.isNull(key) && record.has(key)) RecordValidation.rank(record.get(key).toString())
            record.optionalString("attachmentID")?.let { require(it in a) { "缺少附件" } }
            require(uniqueExams.add(listOf(record.getString("subjectID"), record.getString("name"), record.getString("date"), record.getString("score").toBigDecimal().stripTrailingZeros().toPlainString()))) { "重复成绩" }
            Instant.parse(record.getString("createdAt")); Instant.parse(record.getString("updatedAt"))
        }
        for (asset in assets) {
            val name = asset.getString("relativePath"); path(name); require(name.startsWith("assets/")) { "资源路径无效" }
            val value = files[name] ?: error("缺少资源")
            require(asset.getInt("byteCount") == value.size && asset.getString("sha256") == sha(value)) { "资源散列不符" }
        }
        require(assets.map { it.getString("relativePath") }.toSet().size == assets.size) { "重复资源路径" }
        require(users.all { user -> terms.any { it.getString("userID") == user.getString("id") } }) { "用户缺少学期" }
        for(mapping in data.getJSONArray("legacyIDMap").objects()) {
            uuid(mapping.getString("sourceDatasetID"))
            val target = when(mapping.getString("entityType")) { "user" -> u; "semester" -> t; "subject" -> s; "exam" -> e; else -> error("未知旧 ID 类型") }
            require(mapping.getString("canonicalID") in target) { "旧 ID 映射引用无效" }
        }
        require(files.keys == (setOf("manifest.json", "data.json", "preferences.json") + assets.map { it.getString("relativePath") })) { "备份有未声明文件" }
        val selectedUser = preferences.optionalString("currentUserID"); val selectedTerm = preferences.optionalString("currentSemesterID")
        require(selectedUser in u && t[selectedTerm]?.getString("userID") == selectedUser) { "备份当前选择无效" }
        preferences.optionalString("wallpaperAssetID")?.let { require(it in a) { "壁纸缺失" } }
        preferences.optJSONObject("platformExtensions")?.optJSONObject("ios")?.optJSONObject("profileAvatars")?.let { avatars ->
            for (user in avatars.keys()) require(user in u && avatars.getString(user) in a) { "用户头像引用无效" }
        }
        return VerifiedArchive(manifest, data, preferences, files)
    }
}
fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
fun JSONObject.optionalString(key: String): String? = if (!has(key) || isNull(key)) null else getString(key)
