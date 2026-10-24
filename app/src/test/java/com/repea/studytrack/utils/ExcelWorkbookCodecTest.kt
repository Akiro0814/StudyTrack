package com.repea.studytrack.utils

import org.apache.poi.xssf.usermodel.XSSFWorkbook
import org.junit.Assert.*
import org.junit.Test

class ExcelWorkbookCodecTest {
    private fun workbook() = XSSFWorkbook().apply {
        createSheet("Grades").createRow(0).apply { listOf("科目", "时间", "分数", "满分", "分类", "班排").forEachIndexed { i, text -> createCell(i).setCellValue(text) } }
    }
    @Test fun corruptDateAndScoreAreReportedInsteadOfTodayAndZero() = workbook().use { book ->
        book.getSheetAt(0).createRow(1).apply { createCell(0).setCellValue("数学"); createCell(1).setCellValue("2026-02-30"); createCell(2).setCellValue("bad") }
        val preview = ExcelWorkbookCodec.preview(book)
        assertTrue(preview.records.isEmpty()); assertTrue(preview.issues.single().startsWith("第 2 行"))
    }
    @Test fun rankNumericCellAndLeapDateRoundTrip() = workbook().use { book ->
        book.getSheetAt(0).createRow(1).apply { createCell(0).setCellValue("数学"); createCell(1).setCellValue("2024-02-29"); createCell(2).setCellValue(85.25); createCell(3).setCellValue(100.0); createCell(4).setCellValue("期中"); createCell(5).setCellValue(12.0) }
        val preview = ExcelWorkbookCodec.preview(book)
        assertTrue(preview.issues.isEmpty()); assertEquals(12, preview.records.single().classRank); assertEquals(85.25, preview.records.single().score, 0.0)
    }
    @Test fun formulasAndUnknownTypesNeverSilentlyConvert() = workbook().use { book ->
        book.getSheetAt(0).createRow(1).apply { createCell(0).setCellValue("数学"); createCell(1).setCellValue("2026-10-24"); createCell(2).cellFormula = "1+1" }
        assertTrue(ExcelWorkbookCodec.preview(book).records.isEmpty())
    }
    @Test fun timestampAndUnknownCategoryRequireVisibleConversionWarnings() = workbook().use { book ->
        book.getSheetAt(0).createRow(1).apply { createCell(0).setCellValue("数学"); createCell(1).setCellValue("2026-10-24 15:30:00"); createCell(2).setCellValue(85.0); createCell(4).setCellValue("模拟考") }
        val preview = ExcelWorkbookCodec.preview(book)
        assertTrue(preview.issues.isEmpty()); assertEquals(2,preview.warnings.size)
        assertEquals("其他",preview.records.single().type)
    }
    @Test fun excel1904EpochIsAcceptedButPhantom1900LeapDayIsRejected() = workbook().use { book ->
        val row = book.getSheetAt(0).createRow(1).apply { createCell(0).setCellValue("数学"); createCell(1).setCellValue(60.0); createCell(2).setCellValue(85.0) }
        assertEquals(1,ExcelWorkbookCodec.preview(book).issues.size)
        val properties = book.ctWorkbook.workbookPr ?: book.ctWorkbook.addNewWorkbookPr()
        properties.date1904 = true; row.getCell(1).setCellValue(0.0)
        val preview = ExcelWorkbookCodec.preview(book)
        assertTrue(preview.issues.isEmpty())
        assertEquals("1904-01-01",java.time.Instant.ofEpochMilli(preview.records.single().date).atZone(java.time.ZoneId.systemDefault()).toLocalDate().toString())
    }
}
