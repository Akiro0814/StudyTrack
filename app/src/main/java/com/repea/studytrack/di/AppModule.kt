package com.repea.studytrack.di

import android.content.Context
import androidx.room.Room
import com.repea.studytrack.data.local.AppDatabase
import com.repea.studytrack.data.local.dao.ExamRecordDao
import com.repea.studytrack.data.local.dao.SemesterDao
import com.repea.studytrack.data.local.dao.SubjectDao
import com.repea.studytrack.data.local.dao.UserDao
import com.repea.studytrack.repository.StudyRepository
import com.repea.studytrack.repository.StudyRepositoryImpl
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "study_track_db"
        ).addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6)
            .build()
    }

    @Provides
    fun provideSubjectDao(database: AppDatabase): SubjectDao {
        return database.subjectDao()
    }

    @Provides
    fun provideExamRecordDao(database: AppDatabase): ExamRecordDao {
        return database.examRecordDao()
    }

    @Provides
    fun provideSemesterDao(database: AppDatabase): SemesterDao {
        return database.semesterDao()
    }

    @Provides
    fun provideUserDao(database: AppDatabase): UserDao {
        return database.userDao()
    }

    @Provides
    @Singleton
    fun provideStudyRepository(
        subjectDao: SubjectDao,
        examRecordDao: ExamRecordDao,
        semesterDao: SemesterDao,
        userDao: UserDao,
        userPreferencesRepository: com.repea.studytrack.repository.UserPreferencesRepository
    ): StudyRepository {
        return StudyRepositoryImpl(
            subjectDao = subjectDao,
            examRecordDao = examRecordDao,
            semesterDao = semesterDao,
            userDao = userDao,
            userPreferencesRepository = userPreferencesRepository
        )
    }
}
