package com.repea.studytrack.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import com.kyant.backdrop.backdrops.LayerBackdrop
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.lens
import com.kyant.backdrop.effects.vibrancy
import com.kyant.backdrop.highlight.Highlight
import com.kyant.backdrop.shadow.Shadow
import com.repea.studytrack.repository.AppThemeStyle
import com.repea.studytrack.ui.theme.BackgroundLight
import com.repea.studytrack.ui.theme.BlobColor1
import com.repea.studytrack.ui.theme.BlobColor2
import com.repea.studytrack.ui.theme.BlobColor3
import com.repea.studytrack.ui.theme.BlobColor4
import com.repea.studytrack.ui.theme.GlassBorderLight
import com.repea.studytrack.ui.theme.GlassLight
import com.repea.studytrack.ui.theme.LocalAppThemeStyle
import coil.compose.AsyncImage

data class LiquidGlassParams(
    val blurRadiusDp: Float = 0f,
    val refractionHeightDp: Float = 15f,
    val refractionAmountDp: Float = 20f,
    val tintAlpha: Float = 0f,
    val borderAlpha: Float = 0.20f,
    val vibrancyEnabled: Boolean = true,
    val chromaticAberration: Boolean = true,
    val backingAlpha: Float = 0.15f,
    val clear: Boolean = false
)

val LocalLayerBackdrop = compositionLocalOf<LayerBackdrop?> { null }
val LocalLiquidGlassParams = compositionLocalOf { LiquidGlassParams() }

@Composable
fun ProvideLiquidGlass(
    backdrop: LayerBackdrop?,
    params: LiquidGlassParams = LiquidGlassParams(),
    content: @Composable () -> Unit
) {
    CompositionLocalProvider(
        LocalLayerBackdrop provides backdrop,
        LocalLiquidGlassParams provides params,
        content = content
    )
}

@Composable
fun LiquidBackground(
    modifier: Modifier = Modifier,
    backdrop: LayerBackdrop? = null,
    themeStyle: AppThemeStyle = AppThemeStyle.PURE_WHITE,
    customWallpaperUri: String? = null,
    content: @Composable BoxScope.() -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxSize()
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .then(if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
            )

            if (themeStyle == AppThemeStyle.LIQUID_GLASS) {
                if (!customWallpaperUri.isNullOrBlank()) {
                    AsyncImage(
                        model = customWallpaperUri,
                        contentDescription = "自定义壁纸",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.background.copy(alpha = 0.24f))
                    )
                }
                Box(
                    modifier = Modifier
                        .size(280.dp)
                        .offset(x = (-48).dp, y = 72.dp)
                        .blur(42.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(MaterialTheme.colorScheme.primary.copy(alpha = 0.09f), Color.Transparent)
                            ),
                            shape = CircleShape
                        )
                )
                Box(
                    modifier = Modifier
                        .size(320.dp)
                        .offset(x = 160.dp, y = 180.dp)
                        .blur(56.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(BlobColor2.copy(alpha = 0.06f), Color.Transparent)
                            ),
                            shape = CircleShape
                        )
                )
                Box(
                    modifier = Modifier
                        .size(220.dp)
                        .offset(x = 96.dp, y = 520.dp)
                        .blur(36.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(BlobColor3.copy(alpha = 0.03f), Color.Transparent)
                            ),
                            shape = CircleShape
                        )
                )
                Box(
                    modifier = Modifier
                        .size(160.dp)
                        .offset(x = (-24).dp, y = 620.dp)
                        .blur(28.dp)
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(BlobColor4.copy(alpha = 0.03f), Color.Transparent)
                            ),
                            shape = CircleShape
                        )
                )
            }
        }

        content()
    }
}

@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    shape: RoundedCornerShape = RoundedCornerShape(24.dp),
    elevation: Dp = 10.dp,
    contentPadding: Dp = 16.dp,
    content: @Composable BoxScope.() -> Unit
) {
    val themeStyle = LocalAppThemeStyle.current
    val backdrop = LocalLayerBackdrop.current
    val params = LocalLiquidGlassParams.current
    val density = LocalDensity.current
    val surfaceColor = MaterialTheme.colorScheme.surface
    val accentColor = MaterialTheme.colorScheme.primary

    val glassModifier = if (themeStyle == AppThemeStyle.LIQUID_GLASS && backdrop != null) {
        val blurPx = with(density) { params.blurRadiusDp.dp.toPx() }
        val refractionHeightPx = with(density) { params.refractionHeightDp.dp.toPx() }
        val refractionAmountPx = with(density) { params.refractionAmountDp.dp.toPx() }
        Modifier
            .drawBackdrop(
                backdrop = backdrop,
                shape = { shape as Shape },
                effects = {
                    if (params.vibrancyEnabled) vibrancy()
                    blur(if(params.clear) blurPx * 0.25f else blurPx)
                    lens(
                        refractionHeight = refractionHeightPx,
                        refractionAmount = refractionAmountPx,
                        chromaticAberration = params.chromaticAberration
                    )
                },
                highlight = { Highlight(width = 1.dp, alpha = params.borderAlpha) },
                shadow = { Shadow(radius = elevation) },
                onDrawSurface = {
                    drawRect(surfaceColor.copy(alpha = params.backingAlpha))
                    val outline = (shape as Shape).createOutline(size, layoutDirection, this)
                    when (outline) {
                        is Outline.Rounded -> {
                            drawRoundRect(
                                color = accentColor.copy(alpha = params.tintAlpha),
                                cornerRadius = outline.roundRect.topLeftCornerRadius
                            )
                        }
                        is Outline.Rectangle -> {
                            drawRect(accentColor.copy(alpha = params.tintAlpha))
                        }
                        is Outline.Generic -> {
                            drawPath(outline.path, accentColor.copy(alpha = params.tintAlpha))
                        }
                    }
                }
            )
    } else {
        if (themeStyle == AppThemeStyle.PURE_WHITE) {
            Modifier
                .shadow(
                    elevation = 18.dp,
                    shape = shape,
                    spotColor = Color(0x260B1020),
                    ambientColor = Color(0x180B1020)
                )
                .clip(shape)
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.94f))
                .border(
                    1.dp,
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.04f),
                    shape
                )
        } else {
            Modifier
                .shadow(
                    elevation = elevation,
                    shape = shape,
                    spotColor = Color(0x120B1020),
                    ambientColor = Color(0x080B1020)
                )
                .clip(shape)
                .background(GlassLight)
                .border(
                    1.dp,
                    Brush.verticalGradient(
                        listOf(
                            GlassBorderLight.copy(alpha = 0.9f),
                            GlassBorderLight.copy(alpha = 0.16f)
                        )
                    ),
                    shape
                )
        }
    }

    Box(
        modifier = modifier
            .then(glassModifier)
            .padding(contentPadding)
    ) {
        content()
    }
}

@Composable
fun GlassButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    shape: RoundedCornerShape = RoundedCornerShape(16.dp),
    enabled: Boolean = true,
    content: @Composable BoxScope.() -> Unit
) {
    val themeStyle = LocalAppThemeStyle.current
    val backdrop = LocalLayerBackdrop.current
    val params = LocalLiquidGlassParams.current
    val density = LocalDensity.current

    if (themeStyle == AppThemeStyle.LIQUID_GLASS && backdrop != null) {
        val blurPx = with(density) { params.blurRadiusDp.dp.toPx() }
        val refractionHeightPx = with(density) { params.refractionHeightDp.dp.toPx() }
        val refractionAmountPx = with(density) { params.refractionAmountDp.dp.toPx() }

        Box(
            modifier = modifier
                .drawBackdrop(
                    backdrop = backdrop,
                    shape = { shape as Shape },
                    effects = {
                        if (params.vibrancyEnabled) vibrancy()
                        blur(blurPx)
                        lens(
                            refractionHeight = refractionHeightPx,
                            refractionAmount = refractionAmountPx,
                            chromaticAberration = params.chromaticAberration
                        )
                    },
                    highlight = { Highlight(width = 0.5.dp, alpha = params.borderAlpha * 0.6f) },
                    shadow = { Shadow(radius = 8.dp, offset = DpOffset(2.dp, 4.dp)) },
                    onDrawSurface = {
                        drawRoundRect(color = Color.White.copy(alpha = params.tintAlpha * 0.7f))
                    }
                )
                .clickable(enabled = enabled) { onClick() }
                .padding(horizontal = 20.dp, vertical = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            content()
        }
    } else {
        Box(
            modifier = modifier
                .shadow(elevation = 12.dp, shape = shape, spotColor = Color(0x260B1020), ambientColor = Color(0x120B1020))
                .clip(shape)
                .background(MaterialTheme.colorScheme.primary)
                .clickable(enabled = enabled) { onClick() }
                .padding(horizontal = 20.dp, vertical = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            content()
        }
    }
}

@Composable
fun GlassContainer(
    modifier: Modifier = Modifier,
    shape: RoundedCornerShape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
    contentPadding: Dp = 0.dp,
    content: @Composable BoxScope.() -> Unit
) {
    val themeStyle = LocalAppThemeStyle.current
    val backdrop = LocalLayerBackdrop.current
    val params = LocalLiquidGlassParams.current
    val density = LocalDensity.current

    val glassModifier = if (themeStyle == AppThemeStyle.LIQUID_GLASS && backdrop != null) {
        val blurPx = with(density) { params.blurRadiusDp.dp.toPx() }
        val refractionHeightPx = with(density) { params.refractionHeightDp.dp.toPx() }
        val refractionAmountPx = with(density) { params.refractionAmountDp.dp.toPx() }
        Modifier
            .drawBackdrop(
                backdrop = backdrop,
                shape = { shape as Shape },
                effects = {
                    vibrancy()
                    blur(blurPx.coerceAtLeast(4f))
                    lens(
                        refractionHeight = refractionHeightPx,
                        refractionAmount = refractionAmountPx,
                        chromaticAberration = params.chromaticAberration
                    )
                },
                highlight = { Highlight(width = 0.5.dp, alpha = params.borderAlpha * 0.5f) },
                shadow = null,
                onDrawSurface = {
                    drawRoundRect(color = Color.White.copy(alpha = 0.45f))
                }
            )
    } else {
        Modifier
            .clip(shape)
            .background(Color.White.copy(alpha = 0.96f))
    }

    Box(
        modifier = modifier
            .then(glassModifier)
            .padding(contentPadding)
    ) {
        content()
    }
}

@Composable
fun GlassDropdownMenu(
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismissRequest,
        modifier = modifier,
        containerColor = Color.Transparent,
        tonalElevation = 0.dp,
        shadowElevation = 0.dp
    ) {
        GlassCard(contentPadding = 8.dp) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp), content = content)
        }
    }
}
