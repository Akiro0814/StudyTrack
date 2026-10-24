package com.repea.studytrack.data.local.dao

import androidx.room.*
import com.repea.studytrack.data.local.entity.PlatformMetadata

@Dao
interface PlatformMetadataDao {
    @Query("SELECT value FROM platform_metadata WHERE `key` = :key") suspend fun get(key: String): String?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun put(value: PlatformMetadata)
    @Query("DELETE FROM platform_metadata WHERE `key` = :key") suspend fun remove(key: String)
}
