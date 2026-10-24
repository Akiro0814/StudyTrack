package com.repea.studytrack.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.repea.studytrack.data.local.dao.ExamRecordDao
import com.repea.studytrack.data.local.dao.SemesterDao
import com.repea.studytrack.data.local.dao.SubjectDao
import com.repea.studytrack.data.local.dao.UserDao
import com.repea.studytrack.data.local.entity.ExamRecord
import com.repea.studytrack.data.local.entity.Semester
import com.repea.studytrack.data.local.entity.Subject
import com.repea.studytrack.data.local.entity.UserProfile

@Database(
    entities = [Subject::class, ExamRecord::class, UserProfile::class, Semester::class, com.repea.studytrack.data.local.entity.PlatformMetadata::class],
    version = 6,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun platformMetadataDao(): com.repea.studytrack.data.local.dao.PlatformMetadataDao
    abstract fun subjectDao(): SubjectDao
    abstract fun examRecordDao(): ExamRecordDao
    abstract fun userDao(): UserDao
    abstract fun semesterDao(): SemesterDao

    companion object {
        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // Preserve legacy timestamps; every new/edited record also stores
                // its calendar date, so travelling cannot move an exam to yesterday.
                db.execSQL("ALTER TABLE exam_records ADD COLUMN dateOnly TEXT")
            }
        }
        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE users ADD COLUMN avatarUri TEXT")
                db.execSQL("ALTER TABLE semesters ADD COLUMN stage TEXT")
                db.execSQL("ALTER TABLE semesters ADD COLUMN schoolYear INTEGER")
                db.execSQL("ALTER TABLE semesters ADD COLUMN half INTEGER")
                db.execSQL("ALTER TABLE subjects ADD COLUMN lineageId TEXT")
                db.execSQL("CREATE TABLE IF NOT EXISTS platform_metadata (`key` TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)")
                for (stage in com.repea.studytrack.domain.SchoolStage.entries) {
                    for (term in com.repea.studytrack.domain.SchoolTerm.catalog(stage)) {
                        db.execSQL("UPDATE semesters SET stage=?, schoolYear=?, half=? WHERE name=?", arrayOf<Any>(stage.wire, term.year, term.half, term.label))
                    }
                }
                db.query("SELECT s.id,s.userId,s.semesterId,s.name,t.stage FROM subjects s JOIN semesters t ON t.id=s.semesterId AND t.userId=s.userId").use { rows ->
                    while(rows.moveToNext()) {
                        val stage = if(rows.isNull(4)) "legacy-${rows.getInt(2)}" else rows.getString(4)
                        val key = "${rows.getInt(1)}|$stage|${com.repea.studytrack.utils.BackupValues.normalized(rows.getString(3))}"
                        val lineage = java.util.UUID.nameUUIDFromBytes(key.toByteArray(Charsets.UTF_8)).toString()
                        db.execSQL("UPDATE subjects SET lineageId=? WHERE id=?", arrayOf<Any>(lineage,rows.getInt(0)))
                    }
                }
            }
        }
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // 创建用户表并插入一个默认用户（ID 固定为 1）
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `users` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `name` TEXT NOT NULL,
                        `createdAt` INTEGER NOT NULL
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    INSERT OR IGNORE INTO `users` (`id`, `name`, `createdAt`)
                    VALUES (1, '默认用户', strftime('%s','now') * 1000)
                    """.trimIndent()
                )

                // 为已有表增加 userId 列，并默认归属到默认用户
                db.execSQL(
                    "ALTER TABLE `subjects` ADD COLUMN `userId` INTEGER NOT NULL DEFAULT 1"
                )
                db.execSQL(
                    "ALTER TABLE `exam_records` ADD COLUMN `userId` INTEGER NOT NULL DEFAULT 1"
                )
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `semesters` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `name` TEXT NOT NULL,
                        `userId` INTEGER NOT NULL DEFAULT 1,
                        `createdAt` INTEGER NOT NULL
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    INSERT OR IGNORE INTO `semesters` (`id`, `name`, `userId`, `createdAt`)
                    VALUES (1, '默认学期', 1, strftime('%s','now') * 1000)
                    """.trimIndent()
                )
                db.execSQL(
                    "ALTER TABLE `subjects` ADD COLUMN `semesterId` INTEGER NOT NULL DEFAULT 1"
                )
                db.execSQL(
                    "ALTER TABLE `exam_records` ADD COLUMN `semesterId` INTEGER NOT NULL DEFAULT 1"
                )
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    UPDATE exam_records
                    SET subjectId = (
                        SELECT MIN(s2.id)
                        FROM subjects s2
                        WHERE s2.name = (
                            SELECT s1.name FROM subjects s1 WHERE s1.id = exam_records.subjectId
                        )
                        AND s2.userId = exam_records.userId
                        AND s2.semesterId = exam_records.semesterId
                    )
                    WHERE EXISTS (
                        SELECT 1
                        FROM subjects s3
                        WHERE s3.id = exam_records.subjectId
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    DELETE FROM subjects
                    WHERE id NOT IN (
                        SELECT MIN(id) FROM subjects GROUP BY name, userId, semesterId
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    UPDATE subjects
                    SET semesterId = (
                        SELECT MIN(s2.id)
                        FROM semesters s2
                        WHERE s2.name = (
                            SELECT s1.name FROM semesters s1 WHERE s1.id = subjects.semesterId
                        )
                        AND s2.userId = subjects.userId
                    )
                    WHERE EXISTS (
                        SELECT 1 FROM semesters s3 WHERE s3.id = subjects.semesterId
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    UPDATE exam_records
                    SET semesterId = (
                        SELECT MIN(s2.id)
                        FROM semesters s2
                        WHERE s2.name = (
                            SELECT s1.name FROM semesters s1 WHERE s1.id = exam_records.semesterId
                        )
                        AND s2.userId = exam_records.userId
                    )
                    WHERE EXISTS (
                        SELECT 1 FROM semesters s3 WHERE s3.id = exam_records.semesterId
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    DELETE FROM semesters
                    WHERE id NOT IN (
                        SELECT MIN(id) FROM semesters GROUP BY name, userId
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    DELETE FROM exam_records
                    WHERE id NOT IN (
                        SELECT MIN(id)
                        FROM exam_records
                        GROUP BY subjectId, examName, examDate, score, userId, semesterId
                    )
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    CREATE UNIQUE INDEX IF NOT EXISTS `index_subjects_name_userId_semesterId`
                    ON `subjects` (`name`, `userId`, `semesterId`)
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    CREATE UNIQUE INDEX IF NOT EXISTS `index_semesters_name_userId`
                    ON `semesters` (`name`, `userId`)
                    """.trimIndent()
                )
                db.execSQL(
                    """
                    CREATE UNIQUE INDEX IF NOT EXISTS `index_exam_records_subjectId_examName_examDate_score_userId_semesterId`
                    ON `exam_records` (`subjectId`, `examName`, `examDate`, `score`, `userId`, `semesterId`)
                    """.trimIndent()
                )
            }
        }
    }
}
