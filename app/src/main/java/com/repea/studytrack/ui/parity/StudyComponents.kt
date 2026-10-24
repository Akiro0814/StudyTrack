@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.repea.studytrack.ui.parity

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.shape.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.*
import com.repea.studytrack.ui.components.GlassCard
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.repea.studytrack.R

val LocalStudySurfaceColors = staticCompositionLocalOf<ColorScheme?> { null }
val LocalCanvasLightText = staticCompositionLocalOf<Boolean?> { null }

fun Modifier.studyBusyBlock(busy: Boolean): Modifier = pointerInput(busy) {
    if(busy) awaitPointerEventScope { while(true) { awaitPointerEvent(PointerEventPass.Initial).changes.forEach { it.consume() } } }
}

@Composable fun StudyPanel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val colors = LocalStudySurfaceColors.current ?: MaterialTheme.colorScheme
    MaterialTheme(colorScheme=colors) { CompositionLocalProvider(LocalContentColor provides colors.onSurface) {
        GlassCard(modifier.fillMaxWidth(), shape = RoundedCornerShape(26.dp), elevation = 2.dp, contentPadding = 20.dp) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
        }
    } }
}
@Composable private fun CanvasContent(content: @Composable () -> Unit) {
    val base = LocalStudySurfaceColors.current ?: MaterialTheme.colorScheme
    val light = LocalCanvasLightText.current
    val colors = if(light == null) base else base.copy(onSurface=if(light) Color.White else Color(0xFF1C1C1E),onSurfaceVariant=if(light) Color(0xFFDDDDDF) else Color(0xFF48484A))
    MaterialTheme(colorScheme=colors) { CompositionLocalProvider(LocalContentColor provides colors.onSurface) { content() } }
}
@Composable fun StudyPage(content: @Composable ColumnScope.() -> Unit) {
    CanvasContent { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.widthIn(max = 720.dp).fillMaxWidth().verticalScroll(rememberScrollState()).imePadding()
            .padding(horizontal = 20.dp).padding(top = 12.dp, bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(28.dp), content = content)
    } }
}
@Composable fun StudyHeading(title: String, detail: String? = null) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        detail?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}
@Composable fun StudyPrimary(title: String, onClick: () -> Unit, enabled: Boolean = true, tag: String = "") {
    Button(onClick, Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag(tag), enabled = enabled, shape = CircleShape,
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp)) { Text(title, style = MaterialTheme.typography.labelLarge) }
}
@Composable fun StudyField(label: String, value: String, onChange: (String) -> Unit, modifier: Modifier = Modifier,
    keyboard: KeyboardType = KeyboardType.Text, multiline: Boolean = false, tag: String = "", placeholder: String = "", enabled: Boolean = true) {
    val requester=remember { BringIntoViewRequester() }
    var focused by remember { mutableStateOf(false) }
    val keyboardHeight=WindowInsets.ime.getBottom(LocalDensity.current)
    LaunchedEffect(focused,keyboardHeight) { if(focused) { kotlinx.coroutines.delay(100); requester.bringIntoView() } }
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        BasicTextField(value, onChange, Modifier.fillMaxWidth().bringIntoViewRequester(requester).onFocusChanged { focused=it.isFocused }.clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.055f)).padding(14.dp).heightIn(min = if (multiline) 80.dp else 24.dp).testTag(tag)
            .semantics { contentDescription = label },
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface), singleLine = !multiline, enabled = enabled,
            keyboardOptions = KeyboardOptions(keyboardType = keyboard), cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
            decorationBox = { inner -> Box { if (value.isEmpty() && placeholder.isNotEmpty()) Text(placeholder, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyLarge); inner() } })
    }
}
@Composable fun StudySegments(labels: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)).padding(3.dp)) {
        labels.forEachIndexed { index, title ->
            val background by animateColorAsState(if (index == selected) MaterialTheme.colorScheme.surface else Color.Transparent, label = "segment")
            Box(Modifier.weight(1f).clip(RoundedCornerShape(8.dp)).background(background).selectable(index == selected, role = Role.Tab, onClick = { onSelect(index) }).heightIn(min = 38.dp).padding(horizontal = 4.dp, vertical = 8.dp), contentAlignment = Alignment.Center) {
                Text(title, style = MaterialTheme.typography.bodySmall, fontWeight = if (index == selected) FontWeight.SemiBold else FontWeight.Normal)
            }
        }
    }
}
@Composable fun StudyRow(title: String, subtitle: String = "", icon: ImageVector? = null, onClick: (() -> Unit)? = null, trailing: @Composable () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).heightIn(min = 52.dp).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        icon?.let { Icon(it, null, Modifier.size(42.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.10f), RoundedCornerShape(13.dp)).padding(11.dp), tint = MaterialTheme.colorScheme.primary) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) { Text(title, style = MaterialTheme.typography.bodyLarge); if (subtitle.isNotBlank()) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        trailing()
        if (onClick != null) Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
@Composable fun StudySwitch(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).toggleable(checked, role = Role.Switch, onValueChange = onChange), verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        val background by animateColorAsState(if (checked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.18f), label = "toggle")
        Box(Modifier.size(51.dp, 31.dp).background(background, CircleShape).padding(2.dp)) {
            Box(Modifier.align(if (checked) Alignment.CenterEnd else Alignment.CenterStart).size(27.dp).background(Color.White, CircleShape))
        }
    }
}
@Composable fun StudyAvatar(name: String, uri: String?, size: Dp = 64.dp) {
    Box(Modifier.size(size).clip(CircleShape).background(MaterialTheme.colorScheme.primary), contentAlignment = Alignment.Center) {
        if (uri != null) AsyncImage(uri, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        else Text(name.take(1).ifBlank { "学" }, color = MaterialTheme.colorScheme.onPrimary, fontSize = (size.value * 0.4).sp, fontWeight = FontWeight.SemiBold)
    }
}
@Composable fun StudyBrand(size: Dp = 72.dp) { Image(painterResource(R.drawable.logo), null, Modifier.size(size).clip(RoundedCornerShape(size * 0.23f))) }
@Composable fun StudyPicker(title: String, value: String, choices: List<String>, onSelect: (Int) -> Unit, tag: String = "") {
    var open by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().testTag(tag).clickable { open = true }.heightIn(min = 48.dp).padding(vertical = 8.dp),verticalAlignment = Alignment.CenterVertically,horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title,Modifier.weight(0.4f),style = MaterialTheme.typography.bodyLarge)
        Text(value,Modifier.weight(0.6f),style = MaterialTheme.typography.bodyMedium,color = MaterialTheme.colorScheme.onSurfaceVariant,textAlign = androidx.compose.ui.text.style.TextAlign.End)
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight,null,Modifier.size(16.dp),tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    if (open) ModalBottomSheet(onDismissRequest = { open = false }, containerColor = MaterialTheme.colorScheme.surface, shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(bottom = 16.dp))
            choices.forEachIndexed { index, text ->
                Row(Modifier.fillMaxWidth().clickable { onSelect(index); open = false }.heightIn(min = 48.dp).padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(text, Modifier.weight(1f)); if (text == value) Icon(Icons.Rounded.Check, null, tint = MaterialTheme.colorScheme.primary)
                }; HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.06f))
            }
        }
    }
}
@Composable fun StudyEmpty(title: String, message: String, action: String? = null, onAction: () -> Unit = {}) {
    StudyPanel {
        Column(Modifier.fillMaxWidth().padding(vertical = 20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Icon(Icons.Rounded.ShowChart, null, Modifier.size(48.dp), tint = MaterialTheme.colorScheme.primary)
            Text(title, style = MaterialTheme.typography.titleMedium); Text(message, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (action != null) StudyPrimary(action, onAction)
        }
    }
}
