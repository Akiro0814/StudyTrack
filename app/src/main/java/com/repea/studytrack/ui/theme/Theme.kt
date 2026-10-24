package com.repea.studytrack.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.graphics.luminance
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.repea.studytrack.repository.AppThemeStyle

val LocalAppThemeStyle = staticCompositionLocalOf { AppThemeStyle.PURE_WHITE }

private val LightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40,
    background = Color.White,
    surface = SurfaceLight,
    surfaceVariant = SurfaceMutedLight,
    onBackground = Color(0xFF111827),
    onSurface = Color(0xFF202634),
    onSurfaceVariant = Color(0xFF7B8497),
    outline = Color(0xFFD7DEEB),
    error = ErrorLight
)

@Composable
fun StudyTrackTheme(
    themeStyle: AppThemeStyle = AppThemeStyle.PURE_WHITE,
    displayMode: String = "system",
    accentHex: String = "#4A66E8",
    content: @Composable () -> Unit
) {
    val dark = displayMode == "dark" || (displayMode == "system" && isSystemInDarkTheme())
    val accent = runCatching { Color(android.graphics.Color.parseColor(accentHex)) }.getOrDefault(Purple40)
    val scheme = if (dark) darkColorScheme(primary = accent, onPrimary = if (accent.luminance() > 0.179f) Color.Black else Color.White,
        background = Color(0xFF000000), surface = Color(0xFF1C1C1E), surfaceVariant = Color(0xFF2C2C2E),
        onSurface = Color(0xFFF2F2F7), onSurfaceVariant = Color(0xFFAEAEB2), outline = Color(0xFF38383A))
    else LightColorScheme.copy(primary = accent, onPrimary = if (accent.luminance() > 0.179f) Color.Black else Color.White,
        background = Color(0xFFF2F2F7), surface = Color.White, surfaceVariant = Color(0xFFECECF0), onSurface = Color(0xFF1C1C1E), onSurfaceVariant = Color(0xFF636366))
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            WindowCompat.setDecorFitsSystemWindows(window, false)
            val controller = WindowCompat.getInsetsController(window, view)
            controller.isAppearanceLightStatusBars = !dark
            controller.isAppearanceLightNavigationBars = !dark
        }
    }

    CompositionLocalProvider(LocalAppThemeStyle provides themeStyle) {
        MaterialTheme(
            colorScheme = scheme,
            typography = Typography,
            content = content
        )
    }
}
