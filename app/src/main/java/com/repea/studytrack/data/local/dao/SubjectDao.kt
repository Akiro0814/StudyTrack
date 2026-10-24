package com.repea.studytrack.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.repea.studytrack.data.local.entity.Subject
import kotlinx.coroutines.flow.Flow

@Dao
interface SubjectDao {
    @Query("SELECT * FROM subjects")
    fun getAllSubjects(): Flow<List<Subject>>

    @Query("SELECT * FROM subjects WHERE id = :id")
    suspend fun getSubjectById(id: Int): Subject?

    @Query("SELECT * FROM subjects WHERE name = :name AND userId = :userId AND semesterId = :semesterId LIMIT 1")
    suspend fun getSubjectByName(name: String, userId: Int, semesterId: Int): Subject?

    @Query("SELECT COUNT(*) FROM subjects WHERE userId = :userId AND semesterId = :semesterId")
    suspend fun countSubjectsInSemester(userId: Int, semesterId: Int): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertSubject(subject: Subject): Long

    @Update
    suspend fun updateSubject(subject: Subject)

    @Delete
    suspend fun deleteSubject(subject: Subject)
}
