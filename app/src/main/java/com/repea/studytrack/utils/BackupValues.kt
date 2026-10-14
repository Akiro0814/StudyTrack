package com.repea.studytrack.utils

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.Normalizer
import java.time.Instant
import java.time.ZoneId

/** Shared v1 exchange rules. Never round historical data during migration. */
object BackupValues {
    fun score(value: Double): String {
        require(value.isFinite() && value >= 0) { "分数必须为非负有限数值" }
        val decimal = BigDecimal.valueOf(value).setScale(2, RoundingMode.UNNECESSARY)
        require(decimal <= BigDecimal("10000000.00")) { "分数超过交换格式范围" }
        return decimal.toPlainString()
    }

    fun normalized(value: String): String = Normalizer.normalize(value.trim(), Normalizer.Form.NFC)

    fun date(timestamp: Long, sourceZone: String): String =
        Instant.ofEpochMilli(timestamp).atZone(ZoneId.of(sourceZone)).toLocalDate().toString()
}
