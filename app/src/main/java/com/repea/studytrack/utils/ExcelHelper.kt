package com.repea.studytrack.utils

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.repea.studytrack.data.local.entity.ExamWithSubject
import com.repea.studytrack.data.local.entity.Subject
import dagger.hilt.android.qualifiers.ApplicationContext
import org.apache.poi.ss.usermodel.WorkbookFactory
import org.apache.poi.xssf.usermodel.XSSFWorkbook
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

class ExcelHelper @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    fun readPreview(uri: Uri): ExcelPreview {
        val bytes = context.contentResolver.openInputStream(uri)?.use { it.readLimited(20*1024*1024) } ?: error("无法读取文件")
        require(bytes.size <= 20*1024*1024) { "Excel 文件超过 20MB" }
        require(bytes.size > 4 && bytes[0] == 0x50.toByte() && bytes[1] == 0x4b.toByte()) { "请选择 .xlsx 工作簿，不支持旧 .xls 格式" }
        return bytes.inputStream().use { input -> XSSFWorkbook(input).use { ExcelWorkbookCodec.preview(it) } }.copy(sourceDigest=BackupArchive.sha(bytes))
    }
    fun exportToUri(
        uri: Uri,
        subjects: List<Subject>,
        records: List<ExamWithSubject>,
        semesterName: String
    ): Boolean {
        val workbook = XSSFWorkbook()
        val sheet = workbook.createSheet("Grades")

        val headerRow = sheet.createRow(0)
        val headers = arrayOf("学期", "科目", "考试名称", "时间", "分数", "满分", "分类", "班排", "年排", "区排", "反思")
        headers.forEachIndexed { index, title ->
            headerRow.createCell(index).setCellValue(title)
        }

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        records.forEachIndexed { index, record ->
            val row = sheet.createRow(index + 1)
            row.createCell(0).setCellValue(semesterName)
            row.createCell(1).setCellValue(record.subject.name)
            row.createCell(2).setCellValue(record.exam.examName)
            row.createCell(3).setCellValue(record.exam.calendarDate())
            row.createCell(4).setCellValue(record.exam.score)
            row.createCell(5).setCellValue(record.subject.fullScore)
            row.createCell(6).setCellValue(record.exam.examType)
            row.createCell(7).setCellValue(record.exam.classRank?.toString() ?: "")
            row.createCell(8).setCellValue(record.exam.gradeRank?.toString() ?: "")
            row.createCell(9).setCellValue(record.exam.districtRank?.toString() ?: "")
            row.createCell(10).setCellValue(record.exam.reflection ?: "")
        }

        return try {
            context.contentResolver.openOutputStream(uri)?.use { 
                workbook.write(it) 
            }
            workbook.close()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun exportToExcel(
        subjects: List<Subject>,
        records: List<ExamWithSubject>,
        semesterName: String
    ): Uri? {
        val workbook = XSSFWorkbook()
        val sheet = workbook.createSheet("Grades")

        val headerRow = sheet.createRow(0)
        val headers = arrayOf("学期", "科目", "考试名称", "时间", "分数", "满分", "分类", "班排", "年排", "区排", "反思")
        headers.forEachIndexed { index, title ->
            headerRow.createCell(index).setCellValue(title)
        }

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        records.forEachIndexed { index, record ->
            val row = sheet.createRow(index + 1)
            row.createCell(0).setCellValue(semesterName)
            row.createCell(1).setCellValue(record.subject.name)
            row.createCell(2).setCellValue(record.exam.examName)
            row.createCell(3).setCellValue(dateFormat.format(Date(record.exam.examDate)))
            row.createCell(4).setCellValue(record.exam.score)
            row.createCell(5).setCellValue(record.subject.fullScore)
            row.createCell(6).setCellValue(record.exam.examType)
            row.createCell(7).setCellValue(record.exam.classRank?.toString() ?: "")
            row.createCell(8).setCellValue(record.exam.gradeRank?.toString() ?: "")
            row.createCell(9).setCellValue(record.exam.districtRank?.toString() ?: "")
            row.createCell(10).setCellValue(record.exam.reflection ?: "")
        }

        // Save
        val filename = "StudyTrack_Backup_${System.currentTimeMillis()}.xlsx"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/StudyTrack")
            }
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            if (uri != null) {
                try {
                    context.contentResolver.openOutputStream(uri)?.use { 
                        workbook.write(it) 
                    }
                    workbook.close()
                    return uri
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                }
            }
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "StudyTrack")
            if (!dir.exists()) dir.mkdirs()
            
            val file = File(dir, filename)
            
            return try {
                val fos = FileOutputStream(file)
                workbook.write(fos)
                fos.close()
                workbook.close()
                Uri.fromFile(file)
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
        return null
    }

    /** 正确格式说明，用于导入失败时引导用户 */
    fun getImportFormatGuide(): String {
        return "请按以下格式制作 Excel：\n\n" +
            "• 首行必须为表头（中文字段名），且至少包含：科目、考试名称、时间、分数\n\n" +
            "• 推荐完整表头顺序：\n" +
            "  1. 学期  2. 科目  3. 考试名称  4. 时间（格式：yyyy-MM-dd）  5. 分数  6. 满分\n" +
            "  7. 分类（如期中/期末）  8. 班排  9. 年排  10. 区排  11. 反思\n\n" +
            "• 学期列可选；若缺失则默认导入到当前所选学期\n\n" +
            "• 从第二行起为数据行；时间需为 yyyy-MM-dd 格式（如 2024-01-15）\n\n" +
            "• 可先使用本应用的「导出成绩到 Excel」生成模板，再按相同格式编辑后导入。"
    }

    /**
     * 校验并导入 Excel。若格式不符合要求则返回 Failure 并附带引导文案。
     */
    fun readExcelWithValidation(uri: Uri): ExcelImportResult {
        return try {
            val inputStream = context.contentResolver.openInputStream(uri)
                ?: return ExcelImportResult.Failure("无法读取文件", getImportFormatGuide())
            val workbook = WorkbookFactory.create(inputStream)
            val sheet = workbook.getSheetAt(0) ?: run {
                workbook.close()
                return ExcelImportResult.Failure("表格为空", getImportFormatGuide())
            }
            val headerRow = sheet.getRow(0) ?: run {
                workbook.close()
                return ExcelImportResult.Failure("缺少表头行", getImportFormatGuide())
            }
            val headerIndex = mutableMapOf<String, Int>()
            headerRow.forEach { cell ->
                val title = cell.stringCellValue?.trim().orEmpty()
                if (title.isNotEmpty()) headerIndex[title] = cell.columnIndex
            }
            val required = listOf("科目", "时间", "分数")
            val missing = required.filter { it !in headerIndex }
            if (missing.isNotEmpty()) {
                workbook.close()
                return ExcelImportResult.Failure(
                    "表头缺少必填列：${missing.joinToString("、")}",
                    getImportFormatGuide()
                )
            }
            val records = readExcel(uri)
            workbook.close()
            if (records.isEmpty()) {
                return ExcelImportResult.Failure("未解析到有效数据行（请检查表头与数据格式）", getImportFormatGuide())
            }
            ExcelImportResult.Success(records)
        } catch (e: Exception) {
            e.printStackTrace()
            ExcelImportResult.Failure("解析失败：${e.message ?: "未知错误"}", getImportFormatGuide())
        }
    }

    fun readExcel(uri: Uri): List<ParsedRecord> {
        val records = mutableListOf<ParsedRecord>()
        try {
            val inputStream = context.contentResolver.openInputStream(uri)
            val workbook = WorkbookFactory.create(inputStream)
            val sheet = workbook.getSheetAt(0) ?: return emptyList()

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

            val headerRow = sheet.getRow(0) ?: return emptyList()
            val headerIndex = mutableMapOf<String, Int>()
            headerRow.forEach { cell ->
                val title = cell.stringCellValue?.trim().orEmpty()
                if (title.isNotEmpty()) {
                    headerIndex[title] = cell.columnIndex
                }
            }

            fun getString(row: org.apache.poi.ss.usermodel.Row, key: String): String? {
                val index = headerIndex[key] ?: return null
                val cell = row.getCell(index) ?: return null
                return cell.toString().takeIf { it.isNotBlank() }
            }

            fun getDouble(row: org.apache.poi.ss.usermodel.Row, key: String): Double? {
                val index = headerIndex[key] ?: return null
                val cell = row.getCell(index) ?: return null
                return cell.toString().toDoubleOrNull()
            }

            for (row in sheet) {
                if (row.rowNum == 0) continue // Skip header

                val subjectName = getString(row, "科目") ?: continue
                val semesterName = getString(row, "学期")
                val examName = getString(row, "考试名称") ?: ""
                val dateStr = getString(row, "时间") ?: ""
                val score = getDouble(row, "分数") ?: 0.0
                val fullScore = getDouble(row, "满分")
                val typeStr = getString(row, "分类") ?: "其他"
                val classRank = getString(row, "班排")?.toIntOrNull()
                val gradeRank = getString(row, "年排")?.toIntOrNull()
                val districtRank = getString(row, "区排")?.toIntOrNull()
                val reflection = getString(row, "反思")

                val date = try {
                    dateFormat.parse(dateStr)?.time ?: System.currentTimeMillis()
                } catch (e: Exception) {
                    System.currentTimeMillis()
                }

                records.add(
                    ParsedRecord(
                        subjectName = subjectName,
                        semesterName = semesterName,
                        examName = examName,
                        date = date,
                        score = score,
                        fullScore = fullScore,
                        type = typeStr,
                        classRank = classRank,
                        gradeRank = gradeRank,
                        districtRank = districtRank,
                        reflection = reflection
                    )
                )
            }
            workbook.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return records
    }
}

sealed class ExcelImportResult {
    data class Success(val records: List<ParsedRecord>) : ExcelImportResult()
    data class Failure(val message: String, val formatGuide: String) : ExcelImportResult()
}

data class ParsedRecord(
    val subjectName: String,
    val semesterName: String?,
    val examName: String,
    val date: Long,
    val score: Double,
    val fullScore: Double?,
    val type: String,
    val classRank: Int?,
    val gradeRank: Int?,
    val districtRank: Int?,
    val reflection: String?
)
