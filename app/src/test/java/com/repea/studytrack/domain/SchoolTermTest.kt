package com.repea.studytrack.domain

import org.junit.Assert.*
import org.junit.Test

class SchoolTermTest {
    @Test fun catalogAndRecognitionMatchIOS() {
        assertEquals(32, SchoolStage.entries.sumOf { SchoolTerm.catalog(it).size })
        assertEquals(SchoolTerm(SchoolStage.HIGH, 1, 1), SchoolTerm.recognize("高一上学期"))
        assertNull(SchoolTerm.recognize("2026 秋"))
        assertEquals("六年级下学期", SchoolTerm(SchoolStage.PRIMARY, 6, 2).label)
    }
    @Test fun progressionStaysInStageAndFillsHoles() {
        val terms = SchoolTerm.catalog(SchoolStage.HIGH)
        assertEquals(terms[1], SchoolTerm.next(SchoolStage.HIGH, listOf(terms[0], terms[5])))
        assertEquals(terms[0], SchoolTerm.next(SchoolStage.HIGH, SchoolTerm.catalog(SchoolStage.JUNIOR)))
        assertNull(SchoolTerm.next(SchoolStage.HIGH, terms))
    }
    @Test fun invalidTermsAndInvalidScoresAreRejected() {
        assertThrows(IllegalArgumentException::class.java) { SchoolTerm(SchoolStage.HIGH, 4, 1) }
        assertEquals(85.25, RecordValidation.score("85.25", 100.0), 0.0)
        for (text in listOf("NaN", "Infinity", "-1", "100.01", "1.001", "")) {
            assertThrows(IllegalArgumentException::class.java) { RecordValidation.score(text, 100.0) }
        }
        assertNull(RecordValidation.rank(""))
        assertThrows(IllegalArgumentException::class.java) { RecordValidation.rank("0") }
    }
    @Test fun dateOnlyRecordsDoNotMoveWhenDeviceTimeZoneChanges() {
        val previous = java.util.TimeZone.getDefault()
        try {
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("Asia/Shanghai"))
            val record = com.repea.studytrack.data.local.entity.ExamRecord(subjectId=1,examName="日期测试",examDate=RecordValidation.date("2026-10-24"),score=80.0,examType="月考",dateOnly="2026-10-24")
            java.util.TimeZone.setDefault(java.util.TimeZone.getTimeZone("America/Los_Angeles"))
            assertEquals("2026-10-24",record.calendarDate())
        } finally { java.util.TimeZone.setDefault(previous) }
    }
}
