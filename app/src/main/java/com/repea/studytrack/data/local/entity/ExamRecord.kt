package com.repea.studytrack.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "exam_records",
    foreignKeys = [
        ForeignKey(
            entity = Subject::class,
            parentColumns = ["id"],
            childColumns = ["subjectId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index("subjectId"),
        Index(value = ["subjectId", "examName", "examDate", "score", "userId", "semesterId"], unique = true)
    ]
)
data class ExamRecord(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val subjectId: Int,
    val examName: String,
    val examDate: Long,
    val score: Double,
    val examType: String, // Stored as label or name
    val classRank: Int? = null,
    val gradeRank: Int? = null,
    val districtRank: Int? = null,
    val reflection: String? = null,
    val imageUri: String? = null,
    val userId: Int = 1,
    val semesterId: Int = 1,
    val dateOnly: String? = null
) {
    fun calendarDate(): String = dateOnly ?: com.repea.studytrack.domain.localDate(examDate)
}
