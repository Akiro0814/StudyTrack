package com.repea.studytrack

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.repea.studytrack.data.local.AppDatabase
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.util.UUID

class MigrationTests {
    @Test fun upgradeV4PreservesRecordsAndLinksOnlyWithinStage() = runBlocking {
        testAccess() // Refuse to touch non-emulator storage.
        val context = ApplicationProvider.getApplicationContext<Context>(); val name = "migration-${UUID.randomUUID()}.sqlite"
        val file = context.getDatabasePath(name); file.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(file,null).use { db ->
            db.execSQL("CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, name TEXT NOT NULL, createdAt INTEGER NOT NULL)")
            db.execSQL("CREATE TABLE semesters (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, name TEXT NOT NULL, userId INTEGER NOT NULL, createdAt INTEGER NOT NULL)")
            db.execSQL("CREATE UNIQUE INDEX index_semesters_name_userId ON semesters(name,userId)")
            db.execSQL("CREATE TABLE subjects (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, name TEXT NOT NULL, fullScore REAL NOT NULL, userId INTEGER NOT NULL, semesterId INTEGER NOT NULL)")
            db.execSQL("CREATE UNIQUE INDEX index_subjects_name_userId_semesterId ON subjects(name,userId,semesterId)")
            db.execSQL("CREATE TABLE exam_records (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, subjectId INTEGER NOT NULL, examName TEXT NOT NULL, examDate INTEGER NOT NULL, score REAL NOT NULL, examType TEXT NOT NULL, classRank INTEGER, gradeRank INTEGER, districtRank INTEGER, reflection TEXT, imageUri TEXT, userId INTEGER NOT NULL, semesterId INTEGER NOT NULL, FOREIGN KEY(subjectId) REFERENCES subjects(id) ON UPDATE NO ACTION ON DELETE CASCADE)")
            db.execSQL("CREATE INDEX index_exam_records_subjectId ON exam_records(subjectId)")
            db.execSQL("CREATE UNIQUE INDEX index_exam_records_subjectId_examName_examDate_score_userId_semesterId ON exam_records(subjectId,examName,examDate,score,userId,semesterId)")
            db.execSQL("INSERT INTO users VALUES(1,'历史学生',1)")
            db.execSQL("INSERT INTO semesters VALUES(1,'高一上学期',1,1),(2,'高一下学期',1,2),(3,'初一上学期',1,3)")
            db.execSQL("INSERT INTO subjects VALUES(11,'数学',100,1,1),(12,'数学',100,1,2),(13,'数学',100,1,3)")
            db.execSQL("INSERT INTO exam_records VALUES(101,11,'历史考试',1792713600000,85.25,'期中',12,NULL,NULL,'旧反思',NULL,1,1)")
            db.version = 4
        }
        val migrated = Room.databaseBuilder(context,AppDatabase::class.java,name).addMigrations(AppDatabase.MIGRATION_4_5,AppDatabase.MIGRATION_5_6).build()
        try {
            val subjects = migrated.subjectDao().getAllSubjects().first().associateBy { it.id }
            assertEquals(subjects.getValue(11).lineageId,subjects.getValue(12).lineageId)
            assertNotEquals(subjects.getValue(11).lineageId,subjects.getValue(13).lineageId)
            val exam = migrated.examRecordDao().getAllRecords().first().single().exam
            assertEquals(101,exam.id); assertEquals(85.25,exam.score,0.0); assertEquals("旧反思",exam.reflection)
            assertEquals("high",migrated.semesterDao().getSemesterById(1)?.stage)
        } finally { migrated.close(); context.deleteDatabase(name) }
    }
}
