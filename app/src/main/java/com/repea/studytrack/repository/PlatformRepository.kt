package com.repea.studytrack.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.room.withTransaction
import com.repea.studytrack.data.local.AppDatabase
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.domain.*
import com.repea.studytrack.utils.ParsedRecord
import com.repea.studytrack.utils.readLimited
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class PlatformScope(val user: Int, val semester: Int)
data class PlatformState(
    val loaded: Boolean = false,
    val users: List<UserProfile> = emptyList(), val semesters: List<Semester> = emptyList(),
    val allSubjects: List<Subject> = emptyList(), val allRecords: List<ExamWithSubject> = emptyList(),
    val preferences: UserPreferencesState = UserPreferencesState()
) {
    val scope get() = PlatformScope(preferences.currentUserId, preferences.currentSemesterId)
    val user get() = users.firstOrNull { it.id == scope.user }
    val semester get() = semesters.firstOrNull { it.userId == scope.user && it.id == scope.semester }
    val userSemesters get() = semesters.filter { it.userId == scope.user }.sortedWith(compareBy({ it.schoolTerm?.stage?.ordinal ?: -1 }, { it.schoolTerm?.order ?: 0 }, { it.createdAt }))
    val subjects get() = allSubjects.filter { it.userId == scope.user && it.semesterId == scope.semester }.sortedBy { it.name }
    val records get() = allRecords.filter { it.exam.userId == scope.user && it.exam.semesterId == scope.semester }.sortedWith(compareByDescending<ExamWithSubject> { it.exam.calendarDate() }.thenByDescending { it.exam.id })
    fun analysis(wholeStage: Boolean): List<SubjectHistory> {
        val stage = semester?.schoolTerm?.stage
        val terms = if (wholeStage && stage != null) userSemesters.filter { it.schoolTerm?.stage == stage }.map { it.id }.toSet() else setOf(scope.semester)
        val subjects = allSubjects.filter { it.userId == scope.user && it.semesterId in terms }
        return subjects.groupBy { "${it.lineageId ?: it.name}|${it.fullScore}" }.map { (key, group) ->
            val ids = group.map { it.id }.toSet()
            SubjectHistory(key, group.firstOrNull { it.semesterId == scope.semester } ?: group.minBy { it.id },
                allRecords.filter { it.exam.userId == scope.user && it.exam.subjectId in ids && it.exam.semesterId in terms }
                    .sortedWith(compareBy({ it.exam.calendarDate() }, { it.exam.id })))
        }.sortedWith(compareBy({ it.subject.name }, { it.subject.fullScore }, { it.key }))
    }
}
data class SubjectHistory(val key: String, val subject: Subject, val records: List<ExamWithSubject>) {
    val average get() = records.map { it.exam.score }.takeIf { it.isNotEmpty() }?.average()
    val maximum get() = records.maxOfOrNull { it.exam.score }
    val excellence get() = if (records.isEmpty()) null else records.count { it.exam.score / subject.fullScore >= 0.85 } * 100 / records.size
}

/** All new UI mutations pass through one scope-checked transaction boundary. */
@Singleton
class PlatformRepository @Inject constructor(
    val database: AppDatabase, val preferences: UserPreferencesRepository,
    @param:ApplicationContext private val context: Context
) {
    val mutationMutex = Mutex()
    val state: Flow<PlatformState> = combine(database.userDao().getAllUsers(), database.semesterDao().getAllSemesters(),
        database.subjectDao().getAllSubjects(), database.examRecordDao().getAllRecords(), preferences.preferences) { u, t, s, r, p ->
        PlatformState(true, u, t, s, r, p)
    }
    suspend fun snapshot() = state.first()
    private suspend fun verify(scope: PlatformScope) {
        val p = preferences.preferences.first()
        require(p.currentUserId == scope.user && p.currentSemesterId == scope.semester) { "学习档案已切换，请重新打开此页面" }
        require(database.semesterDao().getSemesterById(scope.semester)?.userId == scope.user) { "学期已不可用" }
    }
    suspend fun initialize() = mutationMutex.withLock {
        val p = preferences.preferences.first()
        if (!p.firstLaunch) {
            val users = database.userDao().getAllUsers().first()
            val user = users.firstOrNull { it.id == p.currentUserId } ?: users.firstOrNull() ?: return@withLock
            database.withTransaction {
                val all = database.semesterDao().getAllSemesters().first()
                for(profile in users) if(all.none { it.userId == profile.id }) database.semesterDao().insertSemester(Semester(name="默认学期",userId=profile.id))
            }
            val terms = database.semesterDao().getAllSemesters().first().filter { it.userId == user.id }
            val term = terms.firstOrNull { it.id == p.currentSemesterId } ?: terms.firstOrNull()
            val termID = term?.id ?: database.semesterDao().insertSemester(Semester(name = "默认学期", userId = user.id)).toInt()
            preferences.selectScope(user.id, termID)
        }
    }
    suspend fun createProfile(name: String, term: SchoolTerm, onboarding: Boolean, avatar: String? = null) = mutationMutex.withLock {
        val cleaned = RecordValidation.name(name)
        val p = preferences.preferences.first()
        val users = database.userDao().getAllUsers().first()
        require(onboarding || p.multiUserEnabled || users.isEmpty()) { "请先开启多用户模式" }
        val scope = database.withTransaction {
            val reusable = if (onboarding && p.firstLaunch && users.size == 1 && database.examRecordDao().getAllRecords().first().isEmpty()) users.first() else null
            val user = reusable?.id ?: database.userDao().insertUser(UserProfile(name = cleaned, avatarUri = avatar)).toInt()
            if (reusable != null) database.userDao().updateUser(reusable.copy(name = cleaned, avatarUri = avatar ?: reusable.avatarUri))
            val existing = database.semesterDao().getAllSemesters().first().firstOrNull { it.userId == user && it.name == term.label }
            val previous = database.semesterDao().getAllSemesters().first().filter { it.userId == user }
            val emptyDefault = previous.singleOrNull()?.takeIf { reusable != null && it.name == "默认学期" && database.subjectDao().countSubjectsInSemester(user,it.id) == 0 }
            val id = existing?.id ?: if(emptyDefault != null) {
                database.semesterDao().updateSemester(emptyDefault.copy(name=term.label,stage=term.stage.wire,schoolYear=term.year,half=term.half)); emptyDefault.id
            } else database.semesterDao().insertSemester(Semester(name = term.label, userId = user, stage = term.stage.wire, schoolYear = term.year, half = term.half)).toInt()
            PlatformScope(user, id)
        }
        preferences.selectScope(scope.user, scope.semester, onboarding)
    }
    suspend fun select(scope: PlatformScope) = mutationMutex.withLock {
        val p = preferences.preferences.first()
        require(p.multiUserEnabled || p.currentUserId == scope.user) { "请先开启多用户模式" }
        require(database.userDao().getUserById(scope.user) != null && database.semesterDao().getSemesterById(scope.semester)?.userId == scope.user) { "学习档案已不可用" }
        preferences.selectScope(scope.user, scope.semester)
    }
    suspend fun saveTerm(term: SchoolTerm, scope: PlatformScope, editingID: Int? = null) = mutationMutex.withLock {
        verify(scope)
        val id = database.withTransaction {
            val terms = database.semesterDao().getAllSemesters().first().filter { it.userId == scope.user }
            require(terms.none { it.id != editingID && (it.schoolTerm == term || it.name == term.label) }) { "此学期已存在" }
            if (editingID != null) {
                val old = terms.first { it.id == editingID }
                database.semesterDao().updateSemester(old.copy(name = term.label, stage = term.stage.wire, schoolYear = term.year, half = term.half))
                val stageIDs = terms.filter { it.id != editingID && it.schoolTerm?.stage == term.stage }.map { it.id }.toSet()
                val subjects = database.subjectDao().getAllSubjects().first().filter { it.userId == scope.user }
                for(subject in subjects.filter { it.semesterId == editingID }) {
                    val related = subjects.filter { it.semesterId in stageIDs && it.name == subject.name && it.fullScore == subject.fullScore }
                    val lineages = related.mapNotNull { it.lineageId }.distinct()
                    if(lineages.size <= 1) {
                        val lineage = lineages.firstOrNull() ?: subject.lineageId ?: UUID.randomUUID().toString()
                        database.subjectDao().updateSubject(subject.copy(lineageId=lineage))
                        for(candidate in related.filter { it.lineageId == null }) database.subjectDao().updateSubject(candidate.copy(lineageId=lineage))
                    }
                }
                editingID
            } else {
                val id = database.semesterDao().insertSemester(Semester(name = term.label, userId = scope.user, stage = term.stage.wire, schoolYear = term.year, half = term.half)).toInt()
                val source = terms.filter { it.schoolTerm?.stage == term.stage }.maxByOrNull { it.schoolTerm?.order ?: 0 }
                if (source != null) for (subject in database.subjectDao().getAllSubjects().first().filter { it.userId == scope.user && it.semesterId == source.id }) {
                    val lineage = subject.lineageId ?: UUID.randomUUID().toString()
                    if (subject.lineageId == null) database.subjectDao().updateSubject(subject.copy(lineageId = lineage))
                    database.subjectDao().insertSubject(subject.copy(id = 0, semesterId = id, lineageId = lineage))
                }
                id
            }
        }
        preferences.selectScope(scope.user, id)
    }
    suspend fun saveSubject(name: String, full: String, scope: PlatformScope, existing: Subject? = null) = mutationMutex.withLock {
        verify(scope)
        val cleaned = RecordValidation.name(name); val maximum = RecordValidation.fullScore(full)
        database.withTransaction {
            require(database.subjectDao().getAllSubjects().first().none { it.userId == scope.user && it.semesterId == scope.semester && it.name == cleaned && it.id != existing?.id }) { "此学期已有同名科目" }
            if (existing == null) {
                val state = snapshot()
                val predecessor = state.allSubjects.firstOrNull { it.userId == scope.user && it.name == cleaned && it.fullScore == maximum && state.semesters.firstOrNull { t -> t.id == it.semesterId }?.schoolTerm?.stage == state.semester?.schoolTerm?.stage }
                val lineage = predecessor?.lineageId ?: UUID.randomUUID().toString()
                if(predecessor != null && predecessor.lineageId == null) database.subjectDao().updateSubject(predecessor.copy(lineageId=lineage))
                database.subjectDao().insertSubject(Subject(name = cleaned, fullScore = maximum, userId = scope.user, semesterId = scope.semester, lineageId = lineage))
            } else {
                require(existing.userId == scope.user && existing.semesterId == scope.semester && database.subjectDao().getSubjectById(existing.id) != null) { "科目已不可用" }
                require(database.examRecordDao().getAllRecords().first().none { it.exam.subjectId == existing.id && it.exam.score > maximum }) { "满分不能低于已有成绩" }
                database.subjectDao().updateSubject(existing.copy(name = cleaned, fullScore = maximum))
            }
        }
    }
    suspend fun saveRecords(records: List<ExamRecord>, expected: PlatformScope) = mutationMutex.withLock {
        verify(expected)
        require(records.isNotEmpty()) { "至少填写一条成绩" }
        database.withTransaction {
            val old = database.examRecordDao().getAllRecords().first().map { it.exam }
            val keys = mutableSetOf<List<Any>>()
            for (original in records) {
                val record = original.copy(dateOnly = original.calendarDate())
                RecordValidation.date(record.calendarDate())
                val subject = database.subjectDao().getSubjectById(record.subjectId) ?: error("科目已删除")
                require(subject.userId == expected.user && record.userId == expected.user && subject.semesterId == record.semesterId) { "成绩与科目不属于同一学习档案" }
                RecordValidation.score(formatScore(record.score), subject.fullScore)
                for (rank in listOf(record.classRank, record.gradeRank, record.districtRank)) require(rank == null || rank > 0) { "排名必须为正整数" }
                require(record.examType in listOf("月考", "期中", "期末", "其他") && record.examName.length <= 100 && (record.reflection?.length ?: 0) <= 10000) { "考试名称、分类或反思无效" }
                if (record.id != 0) require(old.any { it.id == record.id && it.userId == record.userId && it.semesterId == record.semesterId }) { "原成绩已删除或移动" }
                val key = listOf(record.subjectId, record.examName.trim(), record.calendarDate())
                require(keys.add(key) && old.none { it.id != record.id && it.subjectId == record.subjectId && it.examName.trim() == record.examName.trim() && it.calendarDate() == record.calendarDate() }) { "同科目同日已有同名考试，请编辑原记录" }
                if (record.id == 0) database.examRecordDao().insertRecord(record) else database.examRecordDao().updateRecord(record)
            }
        }
    }
    suspend fun deleteRecord(record: ExamRecord, expected: PlatformScope) = mutationMutex.withLock {
        verify(expected); require(record.userId == expected.user)
        database.examRecordDao().deleteRecord(record)
    }
    suspend fun restoreRecord(record: ExamRecord, expected: PlatformScope) = saveRecords(listOf(record.copy(id = 0)), expected)
    suspend fun deleteSubject(subject: Subject, expected: PlatformScope) = mutationMutex.withLock {
        verify(expected); require(subject.userId == expected.user && subject.semesterId == expected.semester)
        database.subjectDao().deleteSubject(subject)
    }
    suspend fun renameUser(user: UserProfile, name: String, avatar: String? = user.avatarUri) = mutationMutex.withLock {
        require(database.userDao().getUserById(user.id) != null) { "用户已删除" }
        database.userDao().updateUser(user.copy(name = RecordValidation.name(name), avatarUri = avatar))
    }
    suspend fun deleteUser(user: UserProfile) = mutationMutex.withLock {
        val users = database.userDao().getAllUsers().first(); require(users.size > 1) { "至少保留一位用户" }
        database.withTransaction {
            for (subject in database.subjectDao().getAllSubjects().first().filter { it.userId == user.id }) database.subjectDao().deleteSubject(subject)
            for (term in database.semesterDao().getAllSemesters().first().filter { it.userId == user.id }) database.semesterDao().deleteSemester(term)
            database.userDao().deleteUser(user)
        }
        val p = preferences.preferences.first()
        if (p.currentUserId == user.id) {
            val target = users.first { it.id != user.id }
            val term = database.semesterDao().getAllSemesters().first().first { it.userId == target.id }
            preferences.selectScope(target.id, term.id)
        }
    }
    suspend fun deleteSemester(term: Semester, expected: PlatformScope) = mutationMutex.withLock {
        verify(expected); require(term.userId == expected.user && term.id != expected.semester) { "当前学期不能删除" }
        database.withTransaction {
            require(database.subjectDao().getAllSubjects().first().none { it.semesterId == term.id && it.userId == expected.user }) { "此学期还有科目或成绩，请先处理数据" }
            for (subject in database.subjectDao().getAllSubjects().first().filter { it.semesterId == term.id && it.userId == expected.user }) database.subjectDao().deleteSubject(subject)
            database.semesterDao().deleteSemester(term)
        }
    }
    suspend fun importRecords(rows: List<ParsedRecord>, expected: PlatformScope): Pair<Int, Int> = mutationMutex.withLock {
        verify(expected)
        database.withTransaction {
            var imported = 0; var skipped = 0
            val allTerms = database.semesterDao().getAllSemesters().first().filter { it.userId == expected.user }.associateBy { it.name }.toMutableMap()
            val allSubjects = database.subjectDao().getAllSubjects().first().filter { it.userId == expected.user }.toMutableList()
            fun examKey(subject: Int,name: String,date: Long) = "$subject|$name|${localDate(date)}"
            val existingRecords = database.examRecordDao().getAllRecords().first().filter { it.exam.userId == expected.user }.associateBy { "${it.exam.subjectId}|${it.exam.examName}|${it.exam.calendarDate()}" }.toMutableMap()
            for (row in rows) {
                val termName = row.semesterName?.takeIf { it.isNotBlank() }
                val selectedTerm = if(termName == null) allTerms.values.first { it.id == expected.semester } else allTerms[termName] ?: run {
                    val st = SchoolTerm.recognize(termName); val created = Semester(name=RecordValidation.name(termName),userId=expected.user,stage=st?.stage?.wire,schoolYear=st?.year,half=st?.half)
                    created.copy(id=database.semesterDao().insertSemester(created).toInt()).also { allTerms[termName] = it }
                }
                val term = selectedTerm.id
                val subject = allSubjects.firstOrNull { it.semesterId == term && it.name == row.subjectName }
                require(subject == null || row.fullScore == null || subject.fullScore == row.fullScore) { "${row.subjectName} 的满分与现有科目不一致" }
                val full = subject?.fullScore ?: row.fullScore ?: 100.0
                RecordValidation.score(formatScore(row.score), full)
                val actualSubject = subject ?: run {
                    val related = allSubjects.firstOrNull { it.name == row.subjectName && it.fullScore == full && allTerms.values.firstOrNull { t -> t.id == it.semesterId }?.schoolTerm?.stage == selectedTerm.schoolTerm?.stage && selectedTerm.schoolTerm != null }
                    val created = Subject(name=RecordValidation.name(row.subjectName),fullScore=full,userId=expected.user,semesterId=term,lineageId=related?.lineageId ?: UUID.randomUUID().toString())
                    created.copy(id=database.subjectDao().insertSubject(created).toInt()).also { allSubjects += it }
                }
                val id = actualSubject.id
                val existing = existingRecords[examKey(id,row.examName,row.date)]
                if (existing != null) {
                    val old = existing.exam
                    require(old.score == row.score && old.examType == row.type && old.classRank == row.classRank && old.gradeRank == row.gradeRank && old.districtRank == row.districtRank && old.reflection.orEmpty() == row.reflection.orEmpty()) { "${row.subjectName} · ${row.examName} 与现有成绩内容冲突，未导入任何行" }; skipped++
                } else {
                    val record = ExamRecord(subjectId = id, examName = row.examName, examDate = row.date, score = row.score, examType = row.type, classRank = row.classRank, gradeRank = row.gradeRank, districtRank = row.districtRank, reflection = row.reflection, userId = expected.user, semesterId = term,dateOnly = localDate(row.date))
                    database.examRecordDao().insertRecord(record); existingRecords[examKey(id,row.examName,row.date)] = ExamWithSubject(record,actualSubject); imported++
                }
            }
            imported to skipped
        }
    }
    suspend fun saveImage(uri: Uri, avatar: Boolean): String = withContext(Dispatchers.IO) {
        val bytes = context.contentResolver.openInputStream(uri)?.use { input -> input.readLimited(50 * 1024 * 1024) } ?: error("无法读取照片")
        require(bytes.size <= 50 * 1024 * 1024) { "照片超过 50MB" }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }; BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "照片格式无效" }
        val maximum = if (avatar) 512 else 2560
        var sample = 1; while (maxOf(bounds.outWidth, bounds.outHeight) / sample > maximum) sample *= 2
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: error("无法解码照片")
        val orientation = runCatching { android.media.ExifInterface(bytes.inputStream()).getAttributeInt(android.media.ExifInterface.TAG_ORIENTATION,android.media.ExifInterface.ORIENTATION_NORMAL) }.getOrDefault(1)
        val matrix = android.graphics.Matrix()
        when(orientation) {
            2 -> matrix.postScale(-1f,1f); 3 -> matrix.postRotate(180f); 4 -> matrix.postScale(1f,-1f)
            5 -> { matrix.postRotate(90f); matrix.postScale(-1f,1f) }; 6 -> matrix.postRotate(90f)
            7 -> { matrix.postRotate(270f); matrix.postScale(-1f,1f) }; 8 -> matrix.postRotate(270f)
        }
        val bitmap = if(matrix.isIdentity) decoded else Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,matrix,true).also { if(it !== decoded) decoded.recycle() }
        val ratio = minOf(1f, maximum.toFloat() / maxOf(bitmap.width, bitmap.height))
        val resized = Bitmap.createScaledBitmap(bitmap, (bitmap.width * ratio).toInt().coerceAtLeast(1), (bitmap.height * ratio).toInt().coerceAtLeast(1), true)
        val directory = File(context.filesDir, "assets").apply { mkdirs() }
        val file = File(directory, "${UUID.randomUUID()}.jpg")
        try { file.outputStream().use { require(resized.compress(Bitmap.CompressFormat.JPEG, 88, it)) } }
        finally { if (resized !== bitmap) resized.recycle(); bitmap.recycle() }
        Uri.fromFile(file).toString()
    }
    suspend fun wallpaperNeedsLightText(uri: String): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val parsed = Uri.parse(uri)
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds=true }
            context.contentResolver.openInputStream(parsed)?.use { BitmapFactory.decodeStream(it,null,bounds) }
            var sample = 1; while(maxOf(bounds.outWidth,bounds.outHeight)/sample > 64) sample *= 2
            val bitmap = context.contentResolver.openInputStream(parsed)?.use { BitmapFactory.decodeStream(it,null,BitmapFactory.Options().apply { inSampleSize=sample }) } ?: return@runCatching false
            try {
                val values = ArrayList<Double>()
                for(y in 0 until bitmap.height) for(x in 0 until bitmap.width) { val pixel=bitmap.getPixel(x,y); values += (android.graphics.Color.red(pixel)*0.2126+android.graphics.Color.green(pixel)*0.7152+android.graphics.Color.blue(pixel)*0.0722)/255 }
                values.sort(); values[values.size/2] < 0.57
            } finally { bitmap.recycle() }
        }.getOrDefault(false)
    }
}
