package com.repea.studytrack

import com.repea.studytrack.repository.PlatformRepository
import com.repea.studytrack.utils.BackupExporterV1
import com.repea.studytrack.utils.BackupRestoreService
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

/** Debug-only access for emulator integration fixtures; absent from release. */
@EntryPoint @InstallIn(SingletonComponent::class)
interface PlatformTestAccess {
    fun repository(): PlatformRepository
    fun backups(): BackupRestoreService
    fun exporter(): BackupExporterV1
}
