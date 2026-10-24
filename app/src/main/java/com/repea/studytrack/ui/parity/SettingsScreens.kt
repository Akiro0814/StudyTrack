@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
package com.repea.studytrack.ui.parity

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.repea.studytrack.R
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.viewmodel.PlatformViewModel
import kotlinx.coroutines.launch

@Composable fun SettingsScreen(state: PlatformState,navigate: (String) -> Unit) {
    StudyPage {
        Column(Modifier.fillMaxWidth().padding(vertical = 20.dp),horizontalAlignment = Alignment.CenterHorizontally,verticalArrangement = Arrangement.spacedBy(12.dp)) {
            StudyBrand(80.dp); Text("学迹",style = MaterialTheme.typography.headlineLarge); Text("StudyTrack",color = MaterialTheme.colorScheme.onSurfaceVariant); Text("留住努力的轨迹。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        StudyPanel { StudyRow(state.user?.name ?: "学习档案","编辑头像与称呼",onClick = { navigate("profile") },trailing = { StudyAvatar(state.user?.name.orEmpty(),state.user?.avatarUri,48.dp) }) }
        StudyPanel {
            StudyHeading("我的学习空间")
            StudyRow("个性化","壁纸、颜色与内容质感",Icons.Rounded.Palette,{ navigate("appearance") })
            StudyRow("用户档案","切换、创建和管理学习者",Icons.Rounded.People,{ navigate("profiles") })
            StudyRow("学习阶段",state.semester?.schoolTerm?.stage?.label ?: "归类历史学期",Icons.Rounded.School,{ navigate("stages") })
            StudyRow("切换学期",state.semester?.name ?: "当前阶段的学期",Icons.Rounded.CalendarMonth,{ navigate("semesters") })
        }
        StudyPanel {
            StudyHeading("安心记录")
            StudyRow("数据与备份","Excel 交换、完整备份与恢复",Icons.Rounded.Storage,{ navigate("data") })
            StudyRow("桌面小组件","添加、选择科目与刷新状态",Icons.Rounded.Widgets,{ navigate("widgets") })
            StudyRow("关于学迹","隐私、支持与开源许可",Icons.Rounded.Info,{ navigate("about") })
            StudyRow("使用引导","回顾全部功能与使用方法",Icons.Rounded.AutoAwesome,{ navigate("guide") })
        }
        Column(Modifier.fillMaxWidth(),horizontalAlignment = Alignment.CenterHorizontally,verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("只属于你的本地学习空间",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
            val context = LocalContext.current
            Text(runCatching { context.packageManager.getPackageInfo(context.packageName,0).versionName }.getOrDefault("StudyTrack").orEmpty(),style = MaterialTheme.typography.labelSmall)
            Text("作者 L1angK1NG",style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable fun SemesterScreen(state: PlatformState,vm: PlatformViewModel) {
    val stage = state.semester?.schoolTerm?.stage
    val terms = state.userSemesters.filter { it.schoolTerm?.stage == stage }
    var deleting by remember { mutableStateOf<Semester?>(null) }; var nextStage by remember { mutableStateOf<SchoolStage?>(null) }
    val next = stage?.let { SchoolTerm.next(it,state.userSemesters.mapNotNull { term -> term.schoolTerm }) }
    StudyPage {
        StudyHeading(stage?.label ?: "待归类学期","这里只切换当前阶段的学期，其他阶段请前往学习阶段。")
        StudyPanel {
            for(term in terms) {
                StudyRow(term.name,if(term.id == state.scope.semester) "正在使用" else "轻点切换",onClick = { vm.run { vm.repository.select(PlatformScope(state.scope.user,term.id)) } })
                if(term.id != state.scope.semester) TextButton(onClick = { deleting = term }) { Text("删除空学期",color = MaterialTheme.colorScheme.error) }
            }
        }
        if(next != null) {
            Text("下一学期：${next.label}。继承本阶段最近学期的科目和满分，成绩独立保存。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
            StudyPrimary("开启下一学期",{ val scope = state.scope; vm.run { vm.repository.saveTerm(next,scope) } },!vm.busy,"semester.next")
        } else if(stage != null && stage != SchoolStage.UNIVERSITY) StudyPrimary("进入下一学习阶段",{ nextStage = SchoolStage.entries.getOrNull(stage.ordinal+1) })
        else Text(if(stage == null) "请先在学习阶段中将旧学期归类。" else "本阶段所有学期均已创建。",color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    deleting?.let { term -> AlertDialog(onDismissRequest = { deleting = null },title = { Text("删除“${term.name}”？") },text = { Text("仅允许删除非当前且没有科目的学期。") },confirmButton = { TextButton(onClick = { val scope = state.scope; vm.run(onSuccess = { deleting = null }) { vm.repository.deleteSemester(term,scope) } }) { Text("删除") } },dismissButton = { TextButton(onClick = { deleting = null }) { Text("取消") } }) }
    nextStage?.let { target -> StageConfirmation(target,vm,state) { nextStage = null } }
}
@Composable fun StageScreen(state: PlatformState,vm: PlatformViewModel) {
    var starting by remember { mutableStateOf<SchoolStage?>(null) }; var classifying by remember { mutableStateOf<Semester?>(null) }
    StudyPage {
        StudyPanel {
            for(stage in SchoolStage.entries) {
                val terms = state.userSemesters.filter { it.schoolTerm?.stage == stage }
                Box(Modifier.testTag("stage.${stage.wire}")) { StudyRow(stage.label,if(terms.isEmpty()) "尚未开启" else "${terms.size} 个已建学期${if(state.semester?.schoolTerm?.stage == stage) " · 正在使用" else ""}",Icons.Rounded.School,onClick = {
                    if(terms.isEmpty()) starting = stage else vm.run { vm.repository.select(PlatformScope(state.scope.user,terms.maxBy { it.schoolTerm?.order ?: 0 }.id)) }
                }) }
            }
        }
        Text("切换阶段进入该阶段最近的已建学期。首次开启阶段创建第一学期，历史成绩始终保留。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        val legacy = state.userSemesters.filter { it.schoolTerm == null }
        if(legacy.isNotEmpty()) StudyPanel { StudyHeading("待归类旧学期"); for(term in legacy) StudyRow(term.name,"保留原科目与成绩",onClick = { classifying = term }) }
    }
    starting?.let { StageConfirmation(it,vm,state) { starting = null } }
    classifying?.let { old ->
        var stage by rememberSaveable(old.id) { mutableIntStateOf(2) }; var term by rememberSaveable(old.id) { mutableIntStateOf(0) }
        val catalog = SchoolTerm.catalog(SchoolStage.entries[stage])
        AlertDialog(onDismissRequest = { classifying = null },title = { Text("归类“${old.name}”") },text = { Column { StudyPicker("学习阶段",SchoolStage.entries[stage].label,SchoolStage.entries.map { it.label },{ stage = it; term = 0 }); StudyPicker("学期",catalog[term].label,catalog.map { it.label },{ term = it }); Text("不会合并已存在的学期。",style = MaterialTheme.typography.bodySmall) } },confirmButton = { TextButton(onClick = { val scope = state.scope; vm.run(onSuccess = { classifying = null }) { vm.repository.saveTerm(catalog[term],scope,old.id) } }) { Text("保存") } },dismissButton = { TextButton(onClick = { classifying = null }) { Text("取消") } })
    }
}
@Composable private fun StageConfirmation(stage: SchoolStage,vm: PlatformViewModel,state: PlatformState,onClose: () -> Unit) {
    AlertDialog(onDismissRequest = onClose,title = { Text("开启${stage.label}？") },text = { Text("创建第一学期，其他阶段的科目与成绩不受影响。") },confirmButton = { TextButton(onClick = { val scope = state.scope; vm.run(onSuccess = onClose) { vm.repository.saveTerm(SchoolTerm(stage,1,1),scope) } }) { Text("开启${stage.label}") } },dismissButton = { TextButton(onClick = onClose) { Text("取消") } })
}

@Composable fun ProfilesScreen(state: PlatformState,vm: PlatformViewModel) {
    var adding by remember { mutableStateOf(false) }; var renaming by remember { mutableStateOf<UserProfile?>(null) }; var deleting by remember { mutableStateOf<UserProfile?>(null) }
    StudyPage {
        StudyPanel { StudySwitch("多用户模式",state.preferences.multiUserEnabled) { vm.run { vm.repository.preferences.setMultiUserEnabled(it) } }; Text("关闭后仍保留已有档案，可重新开启。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant) }
        for(user in state.users) StudyPanel {
            StudyRow(user.name,if(user.id == state.scope.user) "正在使用" else "轻点切换学习档案",onClick = { val term = state.semesters.filter { it.userId == user.id }.minByOrNull { it.createdAt }; if(term != null) vm.run { vm.repository.select(PlatformScope(user.id,term.id)) } })
            Row { TextButton(onClick = { renaming = user }) { Text("重命名") }; if(state.users.size > 1) TextButton(onClick = { deleting = user }) { Text("删除用户",color = MaterialTheme.colorScheme.error) } }
        }
        if(state.preferences.multiUserEnabled) StudyPrimary("添加用户",{ adding = true })
    }
    if(adding) {
        var name by rememberSaveable { mutableStateOf("") }; var stage by rememberSaveable { mutableIntStateOf(2) }; var term by rememberSaveable { mutableIntStateOf(0) }
        val catalog = SchoolTerm.catalog(SchoolStage.entries[stage])
        AlertDialog(onDismissRequest = { adding = false },title = { Text("添加学习档案") },text = { Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { StudyField("姓名或昵称",name,{ name = it }); StudyPicker("学习阶段",SchoolStage.entries[stage].label,SchoolStage.entries.map { it.label },{ stage = it; term = 0 }); StudyPicker("学期",catalog[term].label,catalog.map { it.label },{ term = it }) } },confirmButton = { TextButton(onClick = { vm.run(onSuccess = { adding = false }) { vm.repository.createProfile(name,catalog[term],false) } },enabled = name.isNotBlank() && !vm.busy) { Text("创建学习档案") } },dismissButton = { TextButton(onClick = { adding = false }) { Text("取消") } })
    }
    renaming?.let { user -> var name by rememberSaveable(user.id) { mutableStateOf(user.name) }; AlertDialog(onDismissRequest = { renaming = null },title = { Text("重命名用户") },text = { StudyField("姓名",name,{ name = it }) },confirmButton = { TextButton(onClick = { vm.run(onSuccess = { renaming = null }) { vm.repository.renameUser(user,name) } }) { Text("保存") } },dismissButton = { TextButton(onClick = { renaming = null }) { Text("取消") } }) }
    deleting?.let { user -> AlertDialog(onDismissRequest = { deleting = null },title = { Text("删除“${user.name}”？") },text = { Text("将删除 ${state.semesters.count { it.userId == user.id }} 个学期、${state.allSubjects.count { it.userId == user.id }} 个科目和 ${state.allRecords.count { it.exam.userId == user.id }} 条成绩。此操作无法撤销。") },confirmButton = { TextButton(onClick = { vm.run(onSuccess = { deleting = null }) { vm.repository.deleteUser(user) } }) { Text("删除用户及全部数据",color = MaterialTheme.colorScheme.error) } },dismissButton = { TextButton(onClick = { deleting = null }) { Text("取消") } }) }
}

@Composable fun ProfileScreen(state: PlatformState,vm: PlatformViewModel) {
    val user = state.user ?: return
    var name by rememberSaveable(user.id) { mutableStateOf(user.name) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri -> if(uri != null) vm.run { val image = vm.repository.saveImage(uri,true); vm.repository.renameUser(user,name,image) } }
    StudyPage {
        StudyPanel {
            Box(Modifier.align(Alignment.CenterHorizontally)) { StudyAvatar(user.name,user.avatarUri,96.dp) }
            TextButton(onClick = { picker.launch("image/*") },Modifier.fillMaxWidth()) { Text("更换头像") }
            if(user.avatarUri != null) TextButton(onClick = { vm.run { vm.repository.renameUser(user,name,null) } },Modifier.fillMaxWidth()) { Text("移除头像",color = MaterialTheme.colorScheme.error) }
            StudyField("姓名或昵称",name,{ name = it },tag = "profile.name")
            StudyPrimary("保存个人资料",{ vm.run(onSuccess = { vm.notice = "个人资料已保存" }) { vm.repository.renameUser(user,name) } },!vm.busy && name.isNotBlank())
        }
        Text("每位用户拥有独立头像，头像会随完整备份保存。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable fun AppearanceScreen(state: PlatformState,vm: PlatformViewModel) {
    val p = state.preferences; val scope = rememberCoroutineScope()
    fun update(action: suspend () -> Unit) { scope.launch { try { action() } catch(e: Exception) { vm.error = e.message } } }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri -> if(uri != null) vm.run { vm.repository.preferences.setCustomWallpaperUri(vm.repository.saveImage(uri,false)) } }
    var custom by rememberSaveable { mutableStateOf(p.accentHex) }
    StudyPage {
        StudyHeading("让学迹，更像你。","你喜欢的颜色、照片和阅读方式。")
        StudyPanel {
            StudyHeading("内容质感")
            StudySegments(listOf("默认","液态玻璃"),if(p.themeStyle == AppThemeStyle.LIQUID_GLASS) 1 else 0) { update { vm.repository.preferences.setThemeStyle(if(it == 0) AppThemeStyle.PURE_WHITE else AppThemeStyle.LIQUID_GLASS) } }
            StudyPicker("显示模式",when(p.displayMode) { "dark" -> "暗色模式"; "light" -> "亮色模式"; else -> "跟随系统" },listOf("跟随系统","亮色模式","暗色模式"),{ update { vm.repository.preferences.setAppearance(mode = listOf("system","light","dark")[it]) } })
        }
        StudyPanel {
            StudyHeading("主题色")
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) { for(hex in listOf("#4A66E8","#1A8F70","#E0523D","#9C5CD1")) Box(Modifier.size(44.dp).background(Color(android.graphics.Color.parseColor(hex)),CircleShape).clickable { custom = hex; update { vm.repository.preferences.setAppearance(accent = hex) } }.then(if(p.accentHex == hex) Modifier.border(3.dp,MaterialTheme.colorScheme.onSurface,CircleShape) else Modifier)) }
            StudyField("自定义颜色 #RRGGBB",custom,{ custom = it },tag = "appearance.accent")
            TextButton(onClick = { update { vm.repository.preferences.setAppearance(accent = custom) } }) { Text("应用颜色") }
        }
        StudyPanel {
            StudyHeading("一张喜欢的壁纸")
            StudyRow(if(p.customWallpaperUri == null) "从照片中选择" else "更换壁纸","铺满学习空间，文字保持清晰",Icons.Rounded.Photo,{ picker.launch("image/*") })
            if(p.customWallpaperUri != null) TextButton(onClick = { update { vm.repository.preferences.setCustomWallpaperUri(null) } }) { Text("移除壁纸",color = MaterialTheme.colorScheme.error) }
        }
        if(p.themeStyle == AppThemeStyle.LIQUID_GLASS) StudyPanel {
            StudyHeading("液态玻璃材质调节","AndroidLiquidGlass · Backdrop")
            StudyPicker("材质",if(p.glassVariant == "clear") "清透" else "常规",listOf("常规","清透"),{ update { vm.repository.preferences.setAppearance(variant = if(it == 0) "regular" else "clear") } })
            StudySlider("模糊强度",p.glassBlurRadiusDp,0f..48f) { update { vm.repository.preferences.setGlassBlurRadiusDp(it) } }
            StudySlider("折射高度",p.glassRefractionHeightDp,0f..48f) { update { vm.repository.preferences.setGlassRefractionHeightDp(it) } }
            StudySlider("折射幅度",p.glassRefractionAmountDp,0f..96f) { update { vm.repository.preferences.setGlassRefractionAmountDp(it) } }
            StudySlider("玻璃染色",p.glassTintAlpha,0f..0.5f) { update { vm.repository.preferences.setGlassTintAlpha(it) } }
            StudySlider("背景支撑",p.glassBacking,0f..0.8f) { update { vm.repository.preferences.setAppearance(backing = it) } }
            StudySlider("边框强度",p.glassBorderAlpha,0f..0.6f) { update { vm.repository.preferences.setGlassBorderAlpha(it) } }
            StudySwitch("增强色彩层次",p.glassVibrancyEnabled) { update { vm.repository.preferences.setGlassVibrancyEnabled(it) } }
            StudySwitch("色差折射",p.glassChromaticAberration) { update { vm.repository.preferences.setGlassChromaticAberration(it) } }
        }
        TextButton(onClick = { update { vm.repository.preferences.resetAppearance() } },Modifier.fillMaxWidth()) { Text("恢复默认外观",color = MaterialTheme.colorScheme.error) }
    }
}
@Composable private fun StudySlider(label: String,value: Float,range: ClosedFloatingPointRange<Float>,onSave: (Float) -> Unit) {
    var current by remember(value) { mutableFloatStateOf(value) }
    Column { Text(label,style = MaterialTheme.typography.bodyMedium); Slider(current,{ current = it },valueRange = range,onValueChangeFinished = { onSave(current) }) }
}

@Composable fun DataScreen(state: PlatformState,vm: PlatformViewModel) {
    var sourceTimeZone by rememberSaveable { mutableStateOf(java.time.ZoneId.systemDefault().id) }
    val xlsx = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { if(it != null) vm.inspectExcel(it) }
    val backup = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { if(it != null) vm.inspectBackup(it) }
    val exportXlsx = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")) { if(it != null) vm.exportExcel(it) }
    val exportBackup = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { if(it != null) vm.exportBackup(it,sourceTimeZone) }
    val exportReport = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { if(it != null) vm.exportImportReport(it) }
    var confirmRestore by remember { mutableStateOf(false) }; var validOnly by remember { mutableStateOf(false) }; var conversions by remember { mutableStateOf(false) }
    LaunchedEffect(vm.importPreview) { validOnly=false; conversions=false }
    StudyPage {
        StudyPanel {
            StudyHeading("Excel 交换",state.semester?.name)
            StudyRow("导入 .xlsx","先检查预览，再保存成绩",Icons.Rounded.FileOpen,{ xlsx.launch(arrayOf("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/octet-stream","application/zip")) })
            StudyRow("导出当前学期","11 列标准格式，也可用作模板",Icons.Rounded.IosShare,{ exportXlsx.launch("学迹-${state.semester?.name ?: "成绩"}-${java.time.LocalDate.now()}.xlsx") })
            Text("学期 · 科目 · 考试名称 · 时间 · 分数 · 满分 · 分类 · 班排 · 年排 · 区排 · 反思\n日期使用 yyyy-MM-dd，分类为月考、期中、期末或其他。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        vm.importPreview?.let { preview -> StudyPanel {
            StudyHeading("导入预览","${preview.excel.records.size} 条有效成绩 · ${preview.excel.issues.size} 行有问题")
            for(issue in preview.excel.issues.take(30)) Text(issue,style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.error)
            if(preview.excel.issues.size > 30) Text("还有 ${preview.excel.issues.size-30} 行错误，请修正工作簿后重新导入。")
            if(preview.excel.issues.isNotEmpty()) StudySwitch("仅导入有效行，跳过错误行",validOnly) { validOnly = it }
            for(warning in preview.excel.warnings.take(30)) Text(warning,style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
            if(preview.excel.warnings.isNotEmpty()) StudySwitch("接受已列出的日期与分类转换",conversions) { conversions=it }
            for(row in preview.excel.records.take(5)) Text("${row.subjectName} · ${row.examName} · ${localDate(row.date)} · ${formatScore(row.score)}",style = MaterialTheme.typography.bodySmall)
            StudyPrimary("确认导入 ${preview.excel.records.size} 条",{ vm.importExcel(validOnly,conversions) },!vm.busy && preview.excel.records.isNotEmpty() && (preview.excel.issues.isEmpty() || validOnly) && (preview.excel.warnings.isEmpty() || conversions),"data.import.confirm")
            TextButton(onClick = { vm.importPreview = null; validOnly = false }) { Text("取消预览") }
        } }
        if(vm.importReport != null) StudyPanel { StudyHeading("导入报告"); StudyRow("导出完整 JSON 报告","保留全部行号、错误与转换说明",Icons.Rounded.Description,{ exportReport.launch("学迹-导入报告-${java.time.LocalDate.now()}.json") }) }
        StudyPanel {
            StudyHeading("完整备份","全部用户、学期、成绩、头像、壁纸和外观设置")
            StudyField("旧版记录的原始时区",sourceTimeZone,{ sourceTimeZone=it },tag="data.source.timezone")
            Text("仅用于确定旧版时间戳对应的考试日期。新版记录已保存固定日期，不受旅行和时区切换影响。",style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
            StudyRow("导出完整备份","兼容 iOS 的 .studytrackbackup 文件",Icons.Rounded.Backup,{ exportBackup.launch("学迹-完整备份-${java.time.LocalDate.now()}.studytrackbackup") })
            StudyRow("从文件恢复","校验文件与资源后显示恢复预览",Icons.Rounded.Restore,{ backup.launch(arrayOf("*/*")) })
            StudyRow("找回恢复前的数据","检查上一次替换前的本机快照",Icons.Rounded.History,vm::inspectRecovery)
        }
        vm.backupPreview?.let { preview -> StudyPanel {
            val counts = preview.archive.manifest.getJSONObject("recordCounts")
            StudyHeading("恢复预览","${counts.getInt("users")} 位用户 · ${counts.getInt("semesters")} 个学期 · ${counts.getInt("examRecords")} 条成绩")
            Text("来源：${preview.archive.manifest.getString("sourcePlatform")}\n${preview.archive.manifest.getString("exportedAt")}",style = MaterialTheme.typography.bodySmall)
            Text("将替换本机全部数据。替换前保存恢复快照；预览后数据发生变化会阻止恢复。",color = MaterialTheme.colorScheme.error)
            StudyPrimary("替换本机数据",{ confirmRestore = true },!vm.busy,"data.restore.confirm")
            TextButton(onClick = { vm.backupPreview = null }) { Text("取消恢复预览") }
        } }
        Text("数据默认保存在本机。备份文件未加密，请妥善保管。Android 不提供 iCloud 云备份；可通过系统文件选择器保存到可用的文档提供商。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
    if(confirmRestore) AlertDialog(onDismissRequest = { confirmRestore = false },title = { Text("确认替换全部数据？") },text = { Text("会先保存本机恢复快照，再安装已经校验的备份。") },confirmButton = { TextButton(onClick = { confirmRestore = false; vm.restoreBackup() }) { Text("确认替换",color = MaterialTheme.colorScheme.error) } },dismissButton = { TextButton(onClick = { confirmRestore = false }) { Text("取消") } })
}
@Composable fun WidgetHelpScreen(vm: PlatformViewModel) {
    StudyPage {
        StudyPanel { StudyHeading("添加到桌面"); Text("长按桌面空白处，选择小组件，搜索“学迹成绩趋势”。添加后可选择用户、学期或学习阶段和科目。不同桌面启动器的入口名称可能不同。") }
        StudyPanel { StudyHeading("刷新与隐私"); Text("成绩、科目、学期或用户改变后会请求刷新。关闭多用户模式后，其他用户的组件会隐藏成绩；重新开启后可恢复。点击组件进入对应成绩分析。系统决定后台更新时机。"); StudyPrimary("立即刷新小组件",{ vm.refreshWidgets(); vm.notice = "已请求刷新桌面小组件" }) }
    }
}
@Composable fun AboutScreen() {
    val context = LocalContext.current
    StudyPage {
        StudyPanel { StudyBrand(64.dp); StudyHeading("学迹 StudyTrack","离线成绩记录与分析 · 让每次努力都有迹可循") }
        StudyPanel { StudyHeading("隐私"); Text("学习数据默认保存在本机，不接入广告或分析服务。导出文件包含个人信息，完整备份默认未加密。使用系统文档提供商时，由对应服务处理你主动选择的文件。") }
        StudyPanel { StudyHeading("支持与开源"); StudyRow("项目主页","反馈时请附版本和重现步骤，避免公开真实姓名与成绩",Icons.Rounded.Code,{ context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://github.com/Akiro0814/StudyTrack"))) }); Text("Jetpack Compose · Room · Apache 2.0\nAndroidLiquidGlass / Backdrop · Apache 2.0\nApache POI · Apache 2.0\nCoil · Apache 2.0",style = MaterialTheme.typography.bodySmall) }
        StudyPanel { StudyHeading("支持作者","如果学迹对你有帮助，可自愿支持后续维护。所有功能无需付费。")
            Image(painterResource(R.drawable.zanshang),"自愿赞赏二维码",Modifier.fillMaxWidth().heightIn(max = 380.dp))
        }
    }
}
