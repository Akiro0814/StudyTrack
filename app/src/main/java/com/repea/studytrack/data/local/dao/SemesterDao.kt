package com.repea.studytrack.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.repea.studytrack.data.local.entity.Semester
import kotlinx.coroutines.flow.Flow

@Dao
interface SemesterDao {
    @Query("SELECT * FROM semesters ORDER BY createdAt ASC")
    fun getAllSemesters(): Flow<List<Semester>>

    @Query("SELECT * FROM semesters WHERE id = :id")
    suspend fun getSemesterById(id: Int): Semester?

    @Query("SELECT * FROM semesters WHERE name = :name AND userId = :userId LIMIT 1")
    suspend fun getSemesterByName(name: String, userId: Int): Semester?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSemester(semester: Semester): Long

    @Update
    suspend fun updateSemester(semester: Semester)

    @Delete
    suspend fun deleteSemester(semester: Semester)
}
