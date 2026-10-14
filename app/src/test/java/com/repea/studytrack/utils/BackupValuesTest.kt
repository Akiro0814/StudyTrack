package com.repea.studytrack.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class BackupValuesTest {
    @Test fun preservesTwoDecimalScoresWithoutRounding() {
        assertEquals("89.50", BackupValues.score(89.5))
        assertEquals("0.00", BackupValues.score(0.0))
        assertThrows(ArithmeticException::class.java) { BackupValues.score(89.501) }
        assertThrows(IllegalArgumentException::class.java) { BackupValues.score(Double.NaN) }
    }

    @Test fun usesConfirmedSourceTimeZone() {
        assertEquals("1970-01-01", BackupValues.date(0L, "Asia/Shanghai"))
        assertEquals("1969-12-31", BackupValues.date(0L, "America/Los_Angeles"))
    }
}
