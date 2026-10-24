package com.repea.studytrack.repository

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.repea.studytrack.data.local.dataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

enum class AppThemeStyle {
    PURE_WHITE,
    LIQUID_GLASS
}

private fun Float.safeRange(default: Float, max: Float): Float = if(isFinite()) coerceIn(0f,max) else default

fun UserPreferencesState.sanitized(): UserPreferencesState = copy(
    glassBlurRadiusDp=glassBlurRadiusDp.safeRange(12f,48f), glassRefractionHeightDp=glassRefractionHeightDp.safeRange(15f,48f),
    glassRefractionAmountDp=glassRefractionAmountDp.safeRange(20f,96f), glassTintAlpha=glassTintAlpha.safeRange(0.08f,0.5f),
    glassBorderAlpha=glassBorderAlpha.safeRange(0.2f,0.6f), glassBacking=glassBacking.safeRange(0.15f,0.8f),
    displayMode=displayMode.takeIf { it in listOf("system","light","dark") } ?: "system",
    accentHex=accentHex.takeIf { Regex("#[0-9a-fA-F]{6}").matches(it) } ?: "#4A66E8",
    glassVariant=glassVariant.takeIf { it in listOf("regular","clear") } ?: "regular"
)

data class UserPreferencesState(
    val themeStyle: AppThemeStyle = AppThemeStyle.PURE_WHITE,
    val customWallpaperUri: String? = null,
    val glassBlurRadiusDp: Float = 12f,
    val glassRefractionHeightDp: Float = 15f,
    val glassRefractionAmountDp: Float = 20f,
    val glassTintAlpha: Float = 0.08f,
    val glassBorderAlpha: Float = 0.20f,
    val glassVibrancyEnabled: Boolean = true,
    val glassChromaticAberration: Boolean = true,
    val multiUserEnabled: Boolean = false,
    val currentUserId: Int = 1,
    val currentSemesterId: Int = 1,
    val displayMode: String = "system",
    val accentHex: String = "#4A66E8",
    val firstLaunch: Boolean = true,
    val glassBacking: Float = 0.15f,
    val glassVariant: String = "regular"
)

@Singleton
class UserPreferencesRepository @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    private val THEME_STYLE = stringPreferencesKey("theme_style")
    private val CUSTOM_WALLPAPER_URI = stringPreferencesKey("custom_wallpaper_uri")
    private val GLASS_BLUR_DP = floatPreferencesKey("glass_blur_dp")
    private val GLASS_REFRACTION_HEIGHT_DP = floatPreferencesKey("glass_refraction_height_dp")
    private val GLASS_REFRACTION_AMOUNT_DP = floatPreferencesKey("glass_refraction_amount_dp")
    private val GLASS_TINT_ALPHA = floatPreferencesKey("glass_tint_alpha")
    private val GLASS_BORDER_ALPHA = floatPreferencesKey("glass_border_alpha")
    private val GLASS_VIBRANCY = booleanPreferencesKey("glass_vibrancy")
    private val GLASS_CHROMATIC = booleanPreferencesKey("glass_chromatic")
    private val MULTI_USER_ENABLED = booleanPreferencesKey("multi_user_enabled")
    private val CURRENT_USER_ID = intPreferencesKey("current_user_id")
    private val CURRENT_SEMESTER_ID = intPreferencesKey("current_semester_id")
    private val DISPLAY_MODE = stringPreferencesKey("display_mode")
    private val ACCENT_HEX = stringPreferencesKey("accent_hex")
    private val FIRST_LAUNCH = booleanPreferencesKey("is_first_launch")
    private val GLASS_BACKING = floatPreferencesKey("glass_backing")
    private val GLASS_VARIANT = stringPreferencesKey("glass_variant")

    val preferences: Flow<UserPreferencesState> = context.dataStore.data.map { p ->
        val themeStyle = runCatching {
            p[THEME_STYLE]?.let { AppThemeStyle.valueOf(it) }
        }.getOrNull() ?: AppThemeStyle.PURE_WHITE
        UserPreferencesState(
            themeStyle = themeStyle,
            customWallpaperUri = p[CUSTOM_WALLPAPER_URI],
            glassBlurRadiusDp = p[GLASS_BLUR_DP] ?: 12f,
            glassRefractionHeightDp = p[GLASS_REFRACTION_HEIGHT_DP] ?: 15f,
            glassRefractionAmountDp = p[GLASS_REFRACTION_AMOUNT_DP] ?: 20f,
            glassTintAlpha = p[GLASS_TINT_ALPHA] ?: 0.08f,
            glassBorderAlpha = p[GLASS_BORDER_ALPHA] ?: 0.20f,
            glassVibrancyEnabled = p[GLASS_VIBRANCY] ?: true,
            glassChromaticAberration = p[GLASS_CHROMATIC] ?: true,
            multiUserEnabled = p[MULTI_USER_ENABLED] ?: false,
            currentUserId = p[CURRENT_USER_ID] ?: 1,
            currentSemesterId = p[CURRENT_SEMESTER_ID] ?: 1,
            displayMode = p[DISPLAY_MODE] ?: "system",
            accentHex = p[ACCENT_HEX] ?: "#4A66E8",
            firstLaunch = p[FIRST_LAUNCH] ?: true,
            glassBacking = p[GLASS_BACKING] ?: 0.15f,
            glassVariant = p[GLASS_VARIANT] ?: "regular"
        ).sanitized()
    }

    suspend fun setThemeStyle(style: AppThemeStyle) {
        context.dataStore.edit { p -> p[THEME_STYLE] = style.name }
    }

    suspend fun setCustomWallpaperUri(uri: String?) {
        context.dataStore.edit { p ->
            if (uri.isNullOrBlank()) {
                p.remove(CUSTOM_WALLPAPER_URI)
            } else {
                p[CUSTOM_WALLPAPER_URI] = uri
            }
        }
    }

    suspend fun setGlassBlurRadiusDp(value: Float) {
        context.dataStore.edit { p -> p[GLASS_BLUR_DP] = value.coerceIn(0f, 48f) }
    }

    suspend fun setGlassRefractionHeightDp(value: Float) {
        context.dataStore.edit { p -> p[GLASS_REFRACTION_HEIGHT_DP] = value.coerceIn(0f, 48f) }
    }

    suspend fun setGlassRefractionAmountDp(value: Float) {
        context.dataStore.edit { p -> p[GLASS_REFRACTION_AMOUNT_DP] = value.coerceIn(0f, 96f) }
    }

    suspend fun setGlassTintAlpha(value: Float) {
        context.dataStore.edit { p -> p[GLASS_TINT_ALPHA] = value.coerceIn(0f, 0.5f) }
    }

    suspend fun setGlassBorderAlpha(value: Float) {
        context.dataStore.edit { p -> p[GLASS_BORDER_ALPHA] = value.coerceIn(0f, 0.6f) }
    }

    suspend fun setGlassVibrancyEnabled(enabled: Boolean) {
        context.dataStore.edit { p -> p[GLASS_VIBRANCY] = enabled }
    }

    suspend fun setGlassChromaticAberration(enabled: Boolean) {
        context.dataStore.edit { p -> p[GLASS_CHROMATIC] = enabled }
    }

    suspend fun setMultiUserEnabled(enabled: Boolean) {
        context.dataStore.edit { p -> p[MULTI_USER_ENABLED] = enabled }
    }

    suspend fun setCurrentUserId(userId: Int) {
        context.dataStore.edit { p -> p[CURRENT_USER_ID] = userId }
    }

    suspend fun setCurrentSemesterId(semesterId: Int) {
        context.dataStore.edit { p -> p[CURRENT_SEMESTER_ID] = semesterId }
    }
    suspend fun selectScope(userId: Int, semesterId: Int, completeOnboarding: Boolean = false) {
        context.dataStore.edit { p ->
            p[CURRENT_USER_ID] = userId; p[CURRENT_SEMESTER_ID] = semesterId
            if (completeOnboarding) p[FIRST_LAUNCH] = false
        }
    }
    suspend fun setAppearance(mode: String? = null, accent: String? = null, backing: Float? = null, variant: String? = null) {
        require(mode == null || mode in listOf("system", "light", "dark"))
        require(accent == null || Regex("#[0-9a-fA-F]{6}").matches(accent)) { "颜色需为 #RRGGBB" }
        context.dataStore.edit { p ->
            mode?.let { p[DISPLAY_MODE] = it }; accent?.let { p[ACCENT_HEX] = it.uppercase() }
            backing?.let { p[GLASS_BACKING] = it.coerceIn(0f, 0.8f) }
            variant?.let { p[GLASS_VARIANT] = it }
        }
    }
    suspend fun resetAppearance() {
        context.dataStore.edit { p ->
            p[THEME_STYLE] = AppThemeStyle.PURE_WHITE.name; p.remove(CUSTOM_WALLPAPER_URI)
            p[DISPLAY_MODE] = "system"; p[ACCENT_HEX] = "#4A66E8"; p[GLASS_VARIANT] = "regular"
            p[GLASS_BLUR_DP] = 12f; p[GLASS_REFRACTION_HEIGHT_DP] = 15f; p[GLASS_REFRACTION_AMOUNT_DP] = 20f
            p[GLASS_TINT_ALPHA] = 0.08f; p[GLASS_BORDER_ALPHA] = 0.2f; p[GLASS_BACKING] = 0.15f
            p[GLASS_VIBRANCY] = true; p[GLASS_CHROMATIC] = true
        }
    }
    suspend fun replace(input: UserPreferencesState) {
        val value = input.sanitized()
        context.dataStore.edit { p ->
            p[CURRENT_USER_ID] = value.currentUserId; p[CURRENT_SEMESTER_ID] = value.currentSemesterId
            p[MULTI_USER_ENABLED] = value.multiUserEnabled; p[FIRST_LAUNCH] = value.firstLaunch
            p[THEME_STYLE] = value.themeStyle.name; p[DISPLAY_MODE] = value.displayMode; p[ACCENT_HEX] = value.accentHex
            p[GLASS_BLUR_DP] = value.glassBlurRadiusDp; p[GLASS_TINT_ALPHA] = value.glassTintAlpha
            p[GLASS_REFRACTION_HEIGHT_DP] = value.glassRefractionHeightDp; p[GLASS_REFRACTION_AMOUNT_DP] = value.glassRefractionAmountDp
            p[GLASS_BORDER_ALPHA] = value.glassBorderAlpha; p[GLASS_VIBRANCY] = value.glassVibrancyEnabled
            p[GLASS_CHROMATIC] = value.glassChromaticAberration; p[GLASS_BACKING] = value.glassBacking; p[GLASS_VARIANT] = value.glassVariant
            if (value.customWallpaperUri == null) p.remove(CUSTOM_WALLPAPER_URI) else p[CUSTOM_WALLPAPER_URI] = value.customWallpaperUri
        }
    }
}

