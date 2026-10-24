package com.repea.studytrack.data.local.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "subjects",
    indices = [
        Index(value = ["name", "userId", "semesterId"], unique = true)
    ]
)
data class Subject(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val fullScore: Double = 100.0,
    val userId: Int = 1,
    val semesterId: Int = 1,
    val lineageId: String? = null
)
