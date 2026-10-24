package com.repea.studytrack.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "platform_metadata")
data class PlatformMetadata(@PrimaryKey val key: String, val value: String)
