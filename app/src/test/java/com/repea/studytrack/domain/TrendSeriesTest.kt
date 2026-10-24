package com.repea.studytrack.domain

import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.repository.SubjectHistory
import org.junit.Assert.*
import org.junit.Test

class TrendSeriesTest {
    @Test fun samplingKeepsEndpointsExtremaAndBoundsRendering() {
        val subject = Subject(id = 1,name = "数学")
        val records = (1..10000).map { index -> ExamWithSubject(ExamRecord(id=index,subjectId=1,examName="考试$index",examDate=RecordValidation.date("2026-10-24"),score=when(index) { 4321 -> 100.0; 7654 -> 0.0; else -> 50.0 },examType="月考",classRank=if(index%2 == 0) index else null),subject) }
        val points = TrendSeries.points(listOf(SubjectHistory("math",subject,records)),0)
        val sample = TrendSeries.sample(points,120)
        assertTrue(sample.size <= 120); assertEquals(points.first(),sample.first()); assertEquals(points.last(),sample.last())
        assertEquals(100.0,sample.maxOf { it.value },0.0); assertEquals(0.0,sample.minOf { it.value },0.0)
        val ranks = TrendSeries.points(listOf(SubjectHistory("math",subject,records)),1)
        assertEquals(5000,ranks.size); assertEquals(2.0,ranks.first().x,0.0)
    }
}
