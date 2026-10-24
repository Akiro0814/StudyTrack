package com.repea.studytrack.data.local.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.repea.studytrack.data.local.entity.ExamRecord
import com.repea.studytrack.data.local.entity.ExamWithSubject
import kotlinx.coroutines.flow.Flow

@Dao
interface ExamRecordDao {
    @Transaction
    @Query("SELECT * FROM exam_records ORDER BY examDate DESC")
    fun getAllRecords(): Flow<List<ExamWithSubject>>

    @Query(
        """
        SELECT COUNT(*) FROM exam_records
        WHERE subjectId = :subjectId
        AND examName = :examName
        AND examDate = :examDate
        AND score = :score
        AND userId = :userId
        AND semesterId = :semesterId
        """
    )
    suspend fun countSameRecord(
        subjectId: Int,
        examName: String,
        examDate: Long,
        score: Double,
        userId: Int,
        semesterId: Int
    ): Int

    @Query("SELECT COUNT(*) FROM exam_records WHERE userId = :userId AND semesterId = :semesterId")
    suspend fun countRecordsInSemester(userId: Int, semesterId: Int): Int

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertRecord(record: ExamRecord)

    @Update
    suspend fun updateRecord(record: ExamRecord)

    @Delete
    suspend fun deleteRecord(record: ExamRecord)
}
