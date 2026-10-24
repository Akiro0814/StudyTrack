package com.repea.studytrack.domain

import com.repea.studytrack.data.local.entity.ExamWithSubject
import com.repea.studytrack.repository.SubjectHistory

data class TrendPoint(val group: Int, val row: ExamWithSubject, val x: Double, val value: Double)
object TrendSeries {
    fun points(groups: List<SubjectHistory>, metric: Int): List<TrendPoint> {
        val rows = groups.flatMap { it.records }.sortedWith(compareBy({ it.exam.calendarDate() }, { it.exam.id }))
        val positions = mutableMapOf<Int,Double>()
        if(groups.size == 1) rows.forEachIndexed { i, row -> positions[row.exam.id] = (i+1).toDouble() }
        else rows.groupBy { it.exam.calendarDate() }.forEach { (date, sameDay) ->
            sameDay.forEachIndexed { index, row -> positions[row.exam.id] = java.time.LocalDate.parse(date).toEpochDay().toDouble() + index.toDouble()/sameDay.size*0.4 }
        }
        return groups.flatMapIndexed { groupIndex, group -> group.records.mapNotNull { row ->
            val value = when(metric) { 1 -> row.exam.classRank?.toDouble(); 2 -> row.exam.gradeRank?.toDouble(); 3 -> row.exam.districtRank?.toDouble(); else -> row.exam.score }
            value?.let { TrendPoint(groupIndex,row,positions.getValue(row.exam.id),it) }
        } }
    }
    fun sample(points: List<TrendPoint>, maximum: Int = 200): List<TrendPoint> {
        require(maximum >= 4)
        if(points.size <= maximum) return points
        val selected = sortedSetOf(0,points.lastIndex)
        val buckets = (maximum-2)/2
        for(bucket in 0 until buckets) {
            val start = 1 + bucket*(points.size-2)/buckets
            val end = 1 + (bucket+1)*(points.size-2)/buckets
            if(start < end) { selected += (start until end).minBy { points[it].value }; selected += (start until end).maxBy { points[it].value } }
        }
        return selected.map(points::get)
    }
}
