package com.repea.studytrack

import android.content.Context
import android.os.Build
import androidx.test.core.app.ApplicationProvider
import com.repea.studytrack.repository.PlatformRepository
import com.repea.studytrack.repository.UserPreferencesState
import com.repea.studytrack.utils.BackupExporterV1
import com.repea.studytrack.utils.BackupRestoreService
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.runBlocking
import androidx.room.withTransaction

fun testAccess(): PlatformTestAccess {
    check(Build.HARDWARE.contains("ranchu") || Build.HARDWARE.contains("goldfish")) { "Integration fixtures must run on an isolated emulator" }
    val context = ApplicationProvider.getApplicationContext<Context>()
    return EntryPointAccessors.fromApplication(context,PlatformTestAccess::class.java)
}
fun clearFixture() = runBlocking {
    val repo = testAccess().repository()
    repo.database.withTransaction { val db = repo.database.openHelper.writableDatabase; for(table in listOf("exam_records","subjects","semesters","users","platform_metadata")) db.execSQL("DELETE FROM $table") }
    repo.preferences.replace(UserPreferencesState(firstLaunch=true))
}
