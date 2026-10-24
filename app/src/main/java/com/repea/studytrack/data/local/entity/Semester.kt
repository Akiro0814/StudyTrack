package com.repea.studytrack.data.local.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "semesters",
    indices = [
        Index(value = ["name", "userId"], unique = true)
    ]
)
data class Semester(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val userId: Int = 1,
    val createdAt: Long = System.currentTimeMillis(),
    val stage: String? = null,
    val schoolYear: Int? = null,
    val half: Int? = null
) {
    val schoolTerm: com.repea.studytrack.domain.SchoolTerm? get() {
        val stage = com.repea.studytrack.domain.SchoolStage.fromWire(stage)
        val year = schoolYear; val semesterHalf = half
        return if (stage != null && year != null && semesterHalf != null) {
            runCatching { com.repea.studytrack.domain.SchoolTerm(stage, year, semesterHalf) }.getOrNull()
        } else com.repea.studytrack.domain.SchoolTerm.recognize(name)
    }
}
