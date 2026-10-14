package com.repea.studytrack.viewmodel

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.repea.studytrack.data.local.entity.ExamRecord
import com.repea.studytrack.data.local.entity.ExamType
import com.repea.studytrack.data.local.entity.Semester
import com.repea.studytrack.data.local.entity.Subject
import com.repea.studytrack.repository.StudyRepository
import com.repea.studytrack.repository.UserPreferencesRepository
import com.repea.studytrack.utils.ExcelHelper
import com.repea.studytrack.utils.ExcelImportResult
import com.repea.studytrack.utils.BackupExporterV1
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val excelHelper: ExcelHelper,
    private val repository: StudyRepository,
    private val prefsRepository: UserPreferencesRepository,
    private val backupExporterV1: BackupExporterV1
) : ViewModel() {

    private var fullBackupRunning = false

    fun exportFullBackup(uri: Uri, sourceZone: String) {
        if (fullBackupRunning) return
        fullBackupRunning = true
        viewModelScope.launch {
            try {
                backupExporterV1.export(uri, sourceZone)
                _exportStatus.emit("完整备份已导出。此文件未加密，请妥善保管。")
            } catch (e: Exception) {
                _exportStatus.emit("完整备份失败：${e.message ?: "无法读取数据或资源"}")
            } finally {
                fullBackupRunning = false
            }
        }
    }

    private val _exportStatus = MutableSharedFlow<String>()
    val exportStatus = _exportStatus.asSharedFlow()

    private val _importResult = MutableSharedFlow<ImportUiResult>()
    val importResult = _importResult.asSharedFlow()

    private val _semesterMessage = MutableSharedFlow<String>()
    val semesterMessage = _semesterMessage.asSharedFlow()

    val semesters = repository.getAllSemesters()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun exportData(uri: Uri) {
        viewModelScope.launch {
            try {
                val subjects = repository.getAllSubjects().first()
                val records = repository.getAllRecords().first()
                val semesterName = semesters.value.firstOrNull {
                    it.id == prefsRepository.preferences.first().currentSemesterId
                }?.name ?: "当前学期"
                val success = excelHelper.exportToUri(uri, subjects, records, semesterName)
                if (success) {
                    _exportStatus.emit("导出成功: $uri")
                } else {
                    _exportStatus.emit("导出失败")
                }
            } catch (e: Exception) {
                _exportStatus.emit("导出出错: ${e.message}")
            }
        }
    }

    // Keep old one for backup if needed, but UI will use new one
    fun backupData() {
        viewModelScope.launch {
            try {
                val subjects = repository.getAllSubjects().first()
                val records = repository.getAllRecords().first()
                val semesterName = semesters.value.firstOrNull {
                    it.id == prefsRepository.preferences.first().currentSemesterId
                }?.name ?: "当前学期"
                val uri = excelHelper.exportToExcel(subjects, records, semesterName)
                if (uri != null) {
                    _exportStatus.emit("备份成功: $uri")
                } else {
                    _exportStatus.emit("备份失败")
                }
            } catch (e: Exception) {
                _exportStatus.emit("备份出错: ${e.message}")
            }
        }
    }

    fun importData(uri: Uri) {
        viewModelScope.launch {
            when (val result = excelHelper.readExcelWithValidation(uri)) {
                is ExcelImportResult.Failure -> {
                    _importResult.emit(ImportUiResult.Failure(result.message, result.formatGuide))
                }
                is ExcelImportResult.Success -> {
                    val originalSemesterId = prefsRepository.preferences.first().currentSemesterId
                    val semesterCache = mutableMapOf<String, Int>()
                    var importedCount = 0
                    var skippedCount = 0

                    try {
                        result.records.forEach { record ->
                            val targetSemesterId = when {
                                record.semesterName.isNullOrBlank() -> originalSemesterId
                                else -> {
                                    semesterCache.getOrPut(record.semesterName.trim()) {
                                        val existing = repository.getSemesterByName(record.semesterName.trim())
                                        existing?.id ?: repository.addSemester(
                                            Semester(name = record.semesterName.trim())
                                        ).toInt()
                                    }
                                }
                            }

                            prefsRepository.setCurrentSemesterId(targetSemesterId)

                            var subjectId = repository.getSubjectByName(record.subjectName)?.id
                            if (subjectId == null) {
                                val fullScore = record.fullScore ?: 100.0
                                val newSubject = Subject(name = record.subjectName, fullScore = fullScore)
                                subjectId = repository.addSubject(newSubject).toInt()
                            }
                            val hasSameRecord = repository.hasSameRecord(
                                subjectId = subjectId,
                                examName = record.examName,
                                examDate = record.date,
                                score = record.score,
                                semesterId = targetSemesterId
                            )
                            if (hasSameRecord) {
                                skippedCount += 1
                            } else {
                                repository.addRecord(
                                    ExamRecord(
                                        subjectId = subjectId,
                                        examName = record.examName,
                                        examDate = record.date,
                                        score = record.score,
                                        examType = ExamType.fromLabel(record.type).label,
                                        classRank = record.classRank,
                                        gradeRank = record.gradeRank,
                                        districtRank = record.districtRank,
                                        reflection = record.reflection,
                                        imageUri = null
                                    )
                                )
                                importedCount += 1
                            }
                        }
                    } finally {
                        prefsRepository.setCurrentSemesterId(originalSemesterId)
                    }
                    _importResult.emit(
                        ImportUiResult.Success(
                            importedCount = importedCount,
                            skippedCount = skippedCount
                        )
                    )
                }
            }
        }
    }

    fun createSemester(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            val existing = repository.getSemesterByName(trimmed)
            val semesterId = if (existing != null) {
                existing.id
            } else {
                repository.addSemester(Semester(name = trimmed)).toInt()
            }
            prefsRepository.setCurrentSemesterId(semesterId)
        }
    }

    fun switchSemester(semesterId: Int) {
        viewModelScope.launch {
            prefsRepository.setCurrentSemesterId(semesterId)
        }
    }

    fun renameSemester(semester: Semester, newName: String) {
        val trimmed = newName.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            val existing = repository.getSemesterByName(trimmed)
            if (existing != null && existing.id != semester.id) {
                _semesterMessage.emit("已存在同名学期，请使用其他名称。")
                return@launch
            }
            repository.updateSemester(semester.copy(name = trimmed))
            _semesterMessage.emit("学期名称已更新。")
        }
    }

    fun deleteSemester(semester: Semester) {
        viewModelScope.launch {
            val currentSemesterId = prefsRepository.preferences.first().currentSemesterId
            if (semester.id == currentSemesterId) {
                _semesterMessage.emit("当前正在使用的学期不能删除。")
                return@launch
            }
            val subjectCount = repository.countSemesterSubjects(semester.id)
            val recordCount = repository.countSemesterRecords(semester.id)
            if (subjectCount > 0 || recordCount > 0) {
                _semesterMessage.emit("该学期仍包含科目或成绩数据，无法直接删除。")
                return@launch
            }
            repository.deleteSemester(semester)
            _semesterMessage.emit("学期已删除。")
        }
    }
}

sealed class ImportUiResult {
    data class Success(
        val importedCount: Int,
        val skippedCount: Int
    ) : ImportUiResult()
    data class Failure(val message: String, val formatGuide: String) : ImportUiResult()
}
