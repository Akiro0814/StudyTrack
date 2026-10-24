package com.repea.studytrack.utils

import com.repea.studytrack.domain.RecordValidation
import org.apache.poi.ss.usermodel.CellType
import org.apache.poi.ss.usermodel.DateUtil
import org.apache.poi.ss.usermodel.Row
import org.apache.poi.ss.usermodel.Workbook
import org.apache.poi.xssf.usermodel.XSSFWorkbook
import java.time.LocalDate
import java.time.ZoneId

data class ExcelPreview(val records: List<ParsedRecord>, val issues: List<String>, val warnings: List<String> = emptyList(), val sourceDigest: String = "")

object ExcelWorkbookCodec {
    fun preview(workbook: Workbook): ExcelPreview {
        require(workbook.numberOfSheets > 0) { "工作簿没有工作表" }
        val sheet = workbook.getSheetAt(0)
        require(sheet.lastRowNum <= 10000) { "单次最多导入 10000 行" }
        val header = sheet.getRow(0) ?: error("缺少表头")
        val columns = mutableMapOf<String, Int>()
        header.forEach { cell ->
            require(cell.cellType == CellType.STRING || cell.cellType == CellType.BLANK) { "表头应为文字" }
            val name = cell.stringCellValue.trim()
            if (name.isNotEmpty()) { require(name !in columns) { "重复表头：$name" }; columns[name] = cell.columnIndex }
        }
        require(listOf("科目", "时间", "分数").all { it in columns }) { "缺少必填列：科目、时间、分数" }
        fun text(row: Row, name: String): String {
            val cell = columns[name]?.let { row.getCell(it) } ?: return ""
            require(cell.cellType != CellType.FORMULA && cell.cellType != CellType.ERROR && cell.cellType != CellType.BOOLEAN) { "$name 不接受公式或错误值" }
            return when (cell.cellType) {
                CellType.NUMERIC -> java.math.BigDecimal.valueOf(cell.numericCellValue).stripTrailingZeros().toPlainString()
                CellType.BLANK -> ""; else -> cell.stringCellValue.trim()
            }
        }
        val records = mutableListOf<ParsedRecord>(); val issues = mutableListOf<String>(); val warnings = mutableListOf<String>()
        for (row in sheet) {
            if (row.rowNum == 0 || row.all { it.cellType == CellType.BLANK || (it.cellType == CellType.STRING && it.stringCellValue.isBlank()) }) continue
            try {
                val rowWarnings = mutableListOf<String>()
                val subject = RecordValidation.name(text(row, "科目"))
                val full = text(row, "满分").takeIf { it.isNotBlank() }?.let(RecordValidation::fullScore)
                val score = RecordValidation.score(text(row, "分数"), full ?: 10_000_000.0)
                val dateCell = row.getCell(columns.getValue("时间")) ?: error("日期为空")
                val date = if (dateCell.cellType == CellType.NUMERIC) {
                    val serial = dateCell.numericCellValue
                    val date1904 = (workbook as? XSSFWorkbook)?.isDate1904 == true
                    require(serial.isFinite() && serial >= (if(date1904) 0 else 1) && (date1904 || kotlin.math.floor(serial) != 60.0)) { "不是有效 Excel 日期" }
                    if(serial % 1.0 != 0.0) rowWarnings += "日期含时间，将仅保留日期"
                    DateUtil.getLocalDateTime(serial, (workbook as? XSSFWorkbook)?.isDate1904 == true).toLocalDate()
                } else {
                    val original = text(row,"时间")
                    runCatching { LocalDate.parse(original) }.getOrElse {
                        val converted = original.replace(' ','T')
                        val parsed = runCatching { java.time.LocalDateTime.parse(converted).toLocalDate() }.getOrElse { java.time.OffsetDateTime.parse(converted).toLocalDate() }
                        rowWarnings += "日期含时间，将仅保留日期"; parsed
                    }
                }
                require(date.year in 1900..2100) { "日期应在 1900–2100 年内" }
                val originalType = text(row,"分类").ifBlank { "其他" }
                val type = if(originalType in listOf("月考","期中","期末","其他")) originalType else "其他".also { rowWarnings += "未知分类“$originalType”将转换为其他" }
                val exam = text(row, "考试名称"); require(exam.length <= 100) { "考试名称超过 100 字" }
                val reflection = text(row, "反思"); require(reflection.length <= 10000) { "反思超过 10000 字" }
                records += ParsedRecord(subject, text(row, "学期").takeIf { it.isNotBlank() }?.let(RecordValidation::name), exam,
                    date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(), score, full, type,
                    RecordValidation.rank(text(row, "班排")), RecordValidation.rank(text(row, "年排")), RecordValidation.rank(text(row, "区排")), reflection.takeIf { it.isNotBlank() })
                warnings += rowWarnings.map { "第 ${row.rowNum+1} 行：$it" }
            } catch (error: Exception) { issues += "第 ${row.rowNum + 1} 行：${error.message ?: "数据格式无效"}" }
        }
        require(records.isNotEmpty() || issues.isNotEmpty()) { "未找到成绩数据行" }
        return ExcelPreview(records, issues, warnings)
    }
}
