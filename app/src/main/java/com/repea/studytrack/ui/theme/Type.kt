package com.repea.studytrack.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.repea.studytrack.R

val AppFontFamily = FontFamily.SansSerif
private val BaseTypography = Typography()

val Typography = Typography(
    displayLarge = BaseTypography.displayLarge.copy(fontFamily = AppFontFamily),
    displayMedium = BaseTypography.displayMedium.copy(fontFamily = AppFontFamily),
    displaySmall = BaseTypography.displaySmall.copy(fontFamily = AppFontFamily),
    headlineLarge = TextStyle(fontFamily = AppFontFamily, fontSize = 34.sp, lineHeight = 41.sp, fontWeight = FontWeight.Bold),
    headlineMedium = TextStyle(fontFamily = AppFontFamily, fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold),
    headlineSmall = TextStyle(fontFamily = AppFontFamily, fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold),
    titleLarge = BaseTypography.titleLarge.copy(fontFamily = AppFontFamily),
    titleMedium = BaseTypography.titleMedium.copy(fontFamily = AppFontFamily),
    titleSmall = BaseTypography.titleSmall.copy(fontFamily = AppFontFamily),
    bodyLarge = TextStyle(
        fontFamily = AppFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 17.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.sp
    ),
    bodyMedium = BaseTypography.bodyMedium.copy(fontFamily = AppFontFamily),
    bodySmall = BaseTypography.bodySmall.copy(fontFamily = AppFontFamily),
    labelLarge = BaseTypography.labelLarge.copy(fontFamily = AppFontFamily),
    labelMedium = BaseTypography.labelMedium.copy(fontFamily = AppFontFamily),
    labelSmall = BaseTypography.labelSmall.copy(fontFamily = AppFontFamily)
)
