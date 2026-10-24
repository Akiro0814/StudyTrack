@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class, androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.repea.studytrack.ui.parity

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.kyant.backdrop.backdrops.rememberLayerBackdrop
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.ui.components.*
import com.repea.studytrack.ui.theme.StudyTrackTheme
import com.repea.studytrack.viewmodel.PlatformViewModel

@Composable fun PlatformApp(deepLink: Uri? = null, linkSequence: Int = 0, vm: PlatformViewModel = hiltViewModel()) {
    val state by vm.state.collectAsState()
    val p = state.preferences
    StudyTrackTheme(p.themeStyle, p.displayMode, p.accentHex) {
        val background = MaterialTheme.colorScheme.background
        val surfaceColors = MaterialTheme.colorScheme
        val canvasLight by produceState<Boolean?>(null,p.customWallpaperUri) { value = p.customWallpaperUri?.let { vm.repository.wallpaperNeedsLightText(it) } }
        val backdrop = rememberLayerBackdrop(graphicsLayer = rememberGraphicsLayer()) { drawRect(background); drawContent() }
        ProvideLiquidGlass(backdrop, LiquidGlassParams(p.glassBlurRadiusDp,p.glassRefractionHeightDp,p.glassRefractionAmountDp,p.glassTintAlpha,p.glassBorderAlpha,p.glassVibrancyEnabled,p.glassChromaticAberration,p.glassBacking,p.glassVariant == "clear")) {
            CompositionLocalProvider(LocalStudySurfaceColors provides surfaceColors,LocalCanvasLightText provides canvasLight) {
            Surface(modifier = Modifier.studyBusyBlock(vm.busy), color = Color.Transparent, contentColor = MaterialTheme.colorScheme.onSurface) {
                LiquidBackground(backdrop = backdrop, themeStyle = AppThemeStyle.LIQUID_GLASS, customWallpaperUri = p.customWallpaperUri) {
                    val ready = state.loaded && vm.initialized
                    val onboarding = p.firstLaunch || state.users.isEmpty()
                    AnimatedContent(targetState = if (!ready) 0 else if (onboarding) 1 else 2,
                        transitionSpec = { (fadeIn(tween(400)) + scaleIn(tween(650), initialScale = 0.92f)).togetherWith(fadeOut(tween(180))) }, label = "first-launch") { destination ->
                        when(destination) {
                            0 -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) { StudyBrand(); if (vm.error == null) CircularProgressIndicator() else TextButton(onClick = vm::initialize) { Text("重新打开") } } }
                            1 -> OnboardingFlow(state,vm)
                            else -> MainWorkspace(state,vm)
                        }
                    }
                    if (vm.busy) Box(Modifier.fillMaxSize(),contentAlignment = Alignment.Center) { CircularProgressIndicator(Modifier.size(28.dp)) }
                }
                if (vm.error != null) AlertDialog(onDismissRequest = { vm.error = null },title = { Text("操作未完成") },text = { Text(vm.error.orEmpty()) },confirmButton = { TextButton(onClick = { vm.error = null }) { Text("好") } })
            }
            }
        }
        LaunchedEffect(state.loaded,vm.initialized,deepLink,linkSequence) { if (state.loaded && vm.initialized && !p.firstLaunch && deepLink != null) vm.openWidget(deepLink) }
    }
}

@Composable private fun MainWorkspace(state: PlatformState, vm: PlatformViewModel) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var navigationHeight by remember { mutableStateOf(100.dp) }
    val density = LocalDensity.current
    var stacks by rememberSaveable { mutableStateOf(List(4) { emptyList<String>() }) }
    val route = stacks[tab].lastOrNull().orEmpty()
    fun navigate(target: String) { stacks = stacks.mapIndexed { i, old -> if (i == tab) old + target else old } }
    fun back() { stacks = stacks.mapIndexed { i, old -> if (i == tab) old.dropLast(1) else old } }
    var editor by rememberSaveable { mutableStateOf<String?>(null) }
    var editingRecord by rememberSaveable { mutableStateOf<Int?>(null) }
    var editingSubject by rememberSaveable { mutableStateOf<Int?>(null) }
    var pendingRecord by rememberSaveable { mutableStateOf<String?>(null) }
    var needsSubject by remember { mutableStateOf(false) }
    fun record(kind: String) { if (vm.state.value.subjects.isEmpty()) { pendingRecord = kind; needsSubject = true } else { editingRecord = null; editor = kind } }
    var previousScope by remember { mutableStateOf(state.scope) }
    LaunchedEffect(state.scope) { if (state.scope != previousScope) { stacks = List(4) { emptyList() }; editor = null; vm.importPreview = null; vm.importReport = null; vm.backupPreview = null; vm.dismissUndo(); previousScope = state.scope } }
    LaunchedEffect(vm.analysisNavigation) { if (vm.analysisNavigation != null) { tab = 2; stacks = stacks.mapIndexed { i, old -> if(i == 2) emptyList() else old } } }
    BackHandler(route.isNotEmpty()) { back() }
    val names = listOf("首页","科目","成绩分析","设置")
    val title = when(route) { "stages" -> "学习阶段"; "semesters" -> "切换学期"; "profiles" -> "用户档案"; "profile" -> "个人资料"; "appearance" -> "个性化"; "data" -> "数据与备份"; "about" -> "关于学迹"; "widgets" -> "小组件"; "guide" -> "使用引导"; "records" -> "全部成绩"; else -> if(tab == 0) "学迹" else names[tab] }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface.copy(alpha=0.82f)).heightIn(min = 52.dp)) {
            Text(title,Modifier.align(Alignment.Center).padding(horizontal = 76.dp,vertical = 15.dp),style = MaterialTheme.typography.titleSmall,fontWeight = FontWeight.SemiBold)
            if(route.isNotEmpty()) IconButton(onClick = { back() },Modifier.align(Alignment.CenterStart).testTag("navigation.back")) { Icon(Icons.AutoMirrored.Rounded.ArrowBackIos,"返回",tint = MaterialTheme.colorScheme.primary) }
            if(route.isEmpty()) {
                if(tab == 0) IconButton(onClick = { navigate("appearance") },Modifier.align(Alignment.CenterEnd)) { Icon(Icons.Rounded.Tune,"个性化",tint = MaterialTheme.colorScheme.primary) }
                if(tab == 1 || tab == 2) IconButton(onClick = { if(tab == 1) { editingSubject = null; editor = "subject" } else record("single") },Modifier.align(Alignment.CenterEnd).testTag(if(tab == 1) "subjects.add" else "analysis.add")) { Icon(Icons.Rounded.Add,"添加",tint = MaterialTheme.colorScheme.primary) }
            }
        }
        Box(Modifier.weight(1f)) {
            AnimatedContent(targetState = "$tab|$route",modifier = Modifier.padding(bottom = if(route.isEmpty()) navigationHeight else 0.dp),transitionSpec = { (fadeIn(tween(180)) + slideInHorizontally(tween(280)) { it/12 }).togetherWith(fadeOut(tween(140))) },label = "navigation") { destination ->
                val parts = destination.split('|'); val activeTab = parts[0].toInt(); val activeRoute = parts[1]
                when(activeRoute) {
                    "semesters" -> SemesterScreen(state,vm)
                    "stages" -> StageScreen(state,vm)
                    "profiles" -> ProfilesScreen(state,vm)
                    "profile" -> ProfileScreen(state,vm)
                    "appearance" -> AppearanceScreen(state,vm)
                    "data" -> DataScreen(state,vm)
                    "about" -> AboutScreen()
                    "widgets" -> WidgetHelpScreen(vm)
                    "guide" -> ProductGuide(onFinish = { back() })
                    "records" -> RecordsScreen(state.records,vm,onEdit = { editingRecord = it.id; editor = "single" })
                    else -> when(activeTab) {
                        0 -> HomeScreen(state, onRecord = ::record, onNavigate = ::navigate, onEdit = { editingRecord = it.id; editor = "single" }, vm = vm)
                        1 -> SubjectsScreen(state,vm,onAdd = { editingSubject = null; editor = "subject" },onEdit = { editingSubject = it.id; editor = "subject" })
                        2 -> AnalysisScreen(state,vm,onRecord = ::record,onEdit = { editingRecord = it.id; editor = "single" })
                        else -> SettingsScreen(state,::navigate)
                    }
                }
            }
            if(route.isEmpty()) Box(Modifier.align(Alignment.BottomCenter).widthIn(max = 560.dp).fillMaxWidth().onSizeChanged { navigationHeight = with(density) { it.height.toDp() } }.navigationBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp)) {
                GlassCard(shape = androidx.compose.foundation.shape.RoundedCornerShape(32.dp),contentPadding = 6.dp,elevation = 4.dp) {
                    Row(Modifier.fillMaxWidth()) {
                        names.forEachIndexed { index,label ->
                            Column(Modifier.weight(1f).clip(CircleShape).background(if(index == tab) MaterialTheme.colorScheme.primary.copy(alpha = 0.12f) else Color.Transparent)
                                .clickable { tab = index }.padding(vertical = 9.dp).testTag("tab.$index").semantics { selected = index == tab }, horizontalAlignment = Alignment.CenterHorizontally,verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                val color = if(index == tab) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                StudyTabGlyph(index,index == tab,color); Text(label,style = MaterialTheme.typography.labelSmall,color = color)
                            }
                        }
                    }
                }
            }
            if(vm.deleted != null) Row(Modifier.align(Alignment.BottomCenter).padding(bottom = if(route.isEmpty()) 102.dp else 16.dp).navigationBarsPadding().clip(CircleShape).background(MaterialTheme.colorScheme.surface).padding(horizontal = 20.dp),verticalAlignment = Alignment.CenterVertically) {
                Text("已删除成绩"); TextButton(onClick = vm::undo) { Text("撤销") }; IconButton(onClick = vm::dismissUndo) { Icon(Icons.Rounded.Close,"关闭") }
            }
        }
    }
    if(needsSubject) AlertDialog(onDismissRequest = { needsSubject = false; pendingRecord = null },title = { Text("先添加一个科目") },text = { Text("设置科目和满分后，会继续刚才的录入。") },confirmButton = { TextButton(onClick = { needsSubject = false; editingSubject = null; editor = "subject" }) { Text("添加科目") } },dismissButton = { TextButton(onClick = { needsSubject = false; pendingRecord = null }) { Text("稍后再说") } })
    if(editor != null) {
        val kind = editor
        val busy by rememberUpdatedState(vm.busy)
        ModalBottomSheet(onDismissRequest = { if(!vm.busy) editor = null },sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true,confirmValueChange = { it != SheetValue.Hidden || !busy }),modifier = Modifier.fillMaxHeight(0.95f).studyBusyBlock(vm.busy),containerColor = MaterialTheme.colorScheme.background) {
            when(kind) {
                "subject" -> SubjectEditor(state,vm,state.allSubjects.firstOrNull { it.id == editingSubject },onClose = { editor = null },onSaved = { editor = pendingRecord; pendingRecord = null })
                "batch" -> BatchEditor(state,vm,onClose = { editor = null })
                else -> ExamEditor(state,vm,state.allRecords.firstOrNull { it.exam.id == editingRecord }?.exam,onClose = { editor = null })
            }
        }
    }
    val snackbar = remember { SnackbarHostState() }
    Box(Modifier.fillMaxSize().navigationBarsPadding(),contentAlignment = Alignment.BottomCenter) { SnackbarHost(snackbar,modifier = Modifier.padding(bottom = 100.dp)) }
    LaunchedEffect(vm.notice) { vm.notice?.let { snackbar.showSnackbar(it); vm.notice = null } }
}
