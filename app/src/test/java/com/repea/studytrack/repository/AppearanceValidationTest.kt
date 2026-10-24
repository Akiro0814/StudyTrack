package com.repea.studytrack.repository

import org.junit.Assert.*
import org.junit.Test

class AppearanceValidationTest {
    @Test fun malformedImportedMaterialsCannotReachTheRenderer() {
        val safe=UserPreferencesState(glassBlurRadiusDp=Float.NaN,glassTintAlpha=Float.POSITIVE_INFINITY,glassBacking=-100f,glassRefractionAmountDp=1000f,displayMode="unknown",accentHex="oops",glassVariant="unknown").sanitized()
        assertEquals(12f,safe.glassBlurRadiusDp,0f); assertEquals(0.08f,safe.glassTintAlpha,0f)
        assertEquals(0f,safe.glassBacking,0f); assertEquals(96f,safe.glassRefractionAmountDp,0f)
        assertEquals("system",safe.displayMode); assertEquals("regular",safe.glassVariant)
        assertEquals("#4A66E8",safe.accentHex)
    }
}
