package com.repea.studytrack.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import com.repea.studytrack.R
import com.repea.studytrack.data.local.entity.Semester
import com.repea.studytrack.data.local.entity.UserProfile
import com.repea.studytrack.repository.AppThemeStyle
import com.repea.studytrack.ui.components.GlassCard
import com.repea.studytrack.ui.components.StudyCircleIconButton
import com.repea.studytrack.ui.components.StudySectionHeader
import com.repea.studytrack.ui.components.StudySettingRow
import com.repea.studytrack.ui.components.StudyTextField
import com.repea.studytrack.ui.components.studyPressable
import com.repea.studytrack.ui.navigation.Screen
import com.repea.studytrack.viewmodel.ImportUiResult
import com.repea.studytrack.viewmodel.SettingsViewModel
import com.repea.studytrack.viewmodel.UserManagerViewModel
import com.repea.studytrack.viewmodel.UserPreferencesViewModel

@Composable
fun SettingsScreen(
    navController: NavController,
    viewModel: SettingsViewModel = hiltViewModel(),
    userManagerViewModel: UserManagerViewModel = hiltViewModel(),
    prefsViewModel: UserPreferencesViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    var showImportHelp by remember { mutableStateOf(false) }
    var showFullBackupConfirm by remember { mutableStateOf(false) }
    var sourceTimeZone by remember { mutableStateOf("Asia/Shanghai") }
    var showUserDialog by remember { mutableStateOf(false) }
    var showSemesterDialog by remember { mutableStateOf(false) }
    var editingUser by remember { mutableStateOf<UserProfile?>(null) }
    var editingSemester by remember { mutableStateOf<Semester?>(null) }
    var deletingSemester by remember { mutableStateOf<Semester?>(null) }
    var userNameInput by remember { mutableStateOf("") }
    var semesterNameInput by remember { mutableStateOf("") }
    var importFailureGuide by remember { mutableStateOf<ImportUiResult.Failure?>(null) }

    val userPrefs by userManagerViewModel.prefs.collectAsState()
    val appPrefs by prefsViewModel.preferences.collectAsState()
    val users by userManagerViewModel.users.collectAsState()
    val semesters by viewModel.semesters.collectAsState()
    val versionName = remember(context) {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "V5.0.0"
    }
    val currentUser = users.firstOrNull { it.id == userPrefs.currentUserId } ?: users.firstOrNull()
    val currentSemester = semesters.firstOrNull { it.id == appPrefs.currentSemesterId } ?: semesters.firstOrNull()

    LaunchedEffect(Unit) {
        viewModel.exportStatus.collect { message ->
            android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_LONG).show()
        }
    }
    LaunchedEffect(Unit) {
        viewModel.importResult.collect { result ->
            when (result) {
                is ImportUiResult.Success -> {
                    val message = buildString {
                        append("导入完成")
                        append("，新增 ")
                        append(result.importedCount)
                        append(" 条")
                        if (result.skippedCount > 0) {
                            append("，跳过重复 ")
                            append(result.skippedCount)
                            append(" 条")
                        }
                    }
                    android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_LONG).show()
                }
                is ImportUiResult.Failure -> {
                    importFailureGuide = result
                }
            }
        }
    }
    LaunchedEffect(Unit) {
        viewModel.semesterMessage.collect { message ->
            android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_LONG).show()
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
        onResult = { uri: Uri? ->
            uri?.let { viewModel.importData(it) }
        }
    )
    val exportLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
        onResult = { uri: Uri? ->
            uri?.let { viewModel.exportData(it) }
        }
    )

    val fullBackupLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/zip"),
        onResult = { uri: Uri? -> uri?.let { viewModel.exportFullBackup(it, sourceTimeZone) } }
    )
    if (showFullBackupConfirm) {
        AlertDialog(
            onDismissRequest = { showFullBackupConfirm = false },
            title = { Text("导出完整迁移备份") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("包括全部用户、学期、空科目、成绩、设置与可读取资源。文件未加密。请确认历史考试日期录入时的原始时区；超精度、日期重复或缺失资源会阻止导出。")
                    StudyTextField(value = sourceTimeZone, onValueChange = { sourceTimeZone = it }, label = "原始时区")
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    if (runCatching { java.time.ZoneId.of(sourceTimeZone) }.isSuccess) {
                        showFullBackupConfirm = false
                        fullBackupLauncher.launch("StudyTrack_${System.currentTimeMillis()}.studytrackbackup")
                    } else {
                        android.widget.Toast.makeText(context, "时区无效，例如 Asia/Shanghai", android.widget.Toast.LENGTH_LONG).show()
                    }
                }) { Text("确认并选择保存位置") }
            },
            dismissButton = { TextButton(onClick = { showFullBackupConfirm = false }) { Text("取消") } }
        )
    }

    if (showUserDialog) {
        AlertDialog(
            onDismissRequest = {
                showUserDialog = false
                editingUser = null
                userNameInput = ""
            },
            title = { Text(if (editingUser == null) "添加用户" else "重命名用户") },
            text = {
                StudyTextField(
                    value = userNameInput,
                    onValueChange = { userNameInput = it },
                    label = "用户名称"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val name = userNameInput.trim()
                        if (name.isNotEmpty()) {
                            val user = editingUser
                            if (user == null) {
                                userManagerViewModel.addUser(name)
                            } else {
                                userManagerViewModel.renameUser(user, name)
                            }
                            showUserDialog = false
                            editingUser = null
                            userNameInput = ""
                        }
                    }
                ) {
                    Text("确定")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showUserDialog = false
                        editingUser = null
                        userNameInput = ""
                    }
                ) {
                    Text("取消")
                }
            }
        )
    }

    if (showSemesterDialog) {
        AlertDialog(
            onDismissRequest = {
                showSemesterDialog = false
                editingSemester = null
                semesterNameInput = ""
            },
            title = { Text(if (editingSemester == null) "创建学期" else "重命名学期") },
            text = {
                StudyTextField(
                    value = semesterNameInput,
                    onValueChange = { semesterNameInput = it },
                    label = "学期名称"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val name = semesterNameInput.trim()
                        if (name.isNotEmpty()) {
                            val semester = editingSemester
                            if (semester == null) {
                                viewModel.createSemester(name)
                            } else {
                                viewModel.renameSemester(semester, name)
                            }
                            showSemesterDialog = false
                            editingSemester = null
                            semesterNameInput = ""
                        }
                    }
                ) {
                    Text("确定")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showSemesterDialog = false
                        editingSemester = null
                        semesterNameInput = ""
                    }
                ) {
                    Text("取消")
                }
            }
        )
    }

    if (importFailureGuide != null) {
        AlertDialog(
            onDismissRequest = { importFailureGuide = null },
            title = { Text("导入失败") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(importFailureGuide!!.message)
                    Text(
                        text = importFailureGuide!!.formatGuide,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { importFailureGuide = null }) {
                    Text("知道了")
                }
            }
        )
    }

    if (deletingSemester != null) {
        AlertDialog(
            onDismissRequest = { deletingSemester = null },
            title = { Text("删除学期") },
            text = {
                Text("确认删除学期“${deletingSemester!!.name}”吗？仅当该学期没有科目和成绩数据时才会真正删除。")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteSemester(deletingSemester!!)
                        deletingSemester = null
                    }
                ) {
                    Text("确认删除")
                }
            },
            dismissButton = {
                TextButton(onClick = { deletingSemester = null }) {
                    Text("取消")
                }
            }
        )
    }

    Scaffold(containerColor = androidx.compose.ui.graphics.Color.Transparent) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 10.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "设置",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "管理主题、学期、数据与个人资料",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(22.dp),
                contentPadding = 16.dp
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.logo),
                        contentDescription = "应用图标",
                        modifier = Modifier
                            .size(64.dp)
                            .clip(RoundedCornerShape(20.dp))
                    )
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = currentUser?.name ?: "学习同学",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = currentSemester?.name ?: "默认学期",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Surface(
                            shape = RoundedCornerShape(999.dp),
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                        ) {
                            Text(
                                text = if (appPrefs.themeStyle == AppThemeStyle.PURE_WHITE) "纯白主题" else "液态玻璃主题",
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                color = MaterialTheme.colorScheme.primary,
                                style = MaterialTheme.typography.labelMedium
                            )
                        }
                    }
                }
            }

            GlassCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp), contentPadding = 14.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    StudySectionHeader(title = "主题外观")
                    ThemeStyleCard(
                        title = "纯白主题",
                        description = "默认纯白背景，干净稳定，适合长时间查看数据",
                        selected = appPrefs.themeStyle == AppThemeStyle.PURE_WHITE,
                        onClick = { prefsViewModel.setThemeStyle(AppThemeStyle.PURE_WHITE) }
                    )
                    ThemeStyleCard(
                        title = "液态玻璃",
                        description = "保留白色基底，增加模糊、半透明与柔和高光层次",
                        selected = appPrefs.themeStyle == AppThemeStyle.LIQUID_GLASS,
                        onClick = { prefsViewModel.setThemeStyle(AppThemeStyle.LIQUID_GLASS) }
                    )
                    StudySettingRow(
                        icon = Icons.Default.WbSunny,
                        title = "外观细节",
                        subtitle = if (appPrefs.themeStyle == AppThemeStyle.LIQUID_GLASS) {
                            "调整液态玻璃模糊、边框与折射参数"
                        } else {
                            "切换到液态玻璃主题后可进一步微调效果"
                        },
                        onClick = { navController.navigate(Screen.Personalization.route) },
                        trailing = {
                            Icon(
                                imageVector = Icons.Default.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    )
                }
            }

            GlassCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp), contentPadding = 14.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    StudySectionHeader(title = "学期管理")
                    StudySettingRow(
                        icon = Icons.Default.School,
                        title = "当前学期",
                        subtitle = currentSemester?.name ?: "暂无学期",
                        trailing = {
                            Text(
                                text = "${semesters.size}",
                                color = MaterialTheme.colorScheme.primary,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    )
                    semesters.forEach { semester ->
                        SemesterRow(
                            semester = semester,
                            selected = semester.id == appPrefs.currentSemesterId,
                            onClick = { viewModel.switchSemester(semester.id) },
                            onEdit = {
                                editingSemester = semester
                                semesterNameInput = semester.name
                                showSemesterDialog = true
                            },
                            onDelete = { deletingSemester = semester }
                        )
                    }
                    Button(
                        onClick = {
                            editingSemester = null
                            semesterNameInput = ""
                            showSemesterDialog = true
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("创建并切换到新学期")
                    }
                }
            }

            GlassCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp), contentPadding = 14.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    StudySectionHeader(title = "数据管理")
                    StudySettingRow(
                        icon = Icons.Default.Storage,
                        title = "导出完整 iOS 迁移备份",
                        subtitle = "全部用户、学期、空科目、设置与资源",
                        onClick = { showFullBackupConfirm = true }
                    )
                    StudySettingRow(
                        icon = Icons.Default.Storage,
                        title = "导出成绩报告",
                        subtitle = "导出当前学期为 Excel 文件",
                        onClick = { exportLauncher.launch("StudyTrack_Export_${System.currentTimeMillis()}.xlsx") }
                    )
                    StudySettingRow(
                        icon = Icons.Default.Storage,
                        title = "导入成绩表",
                        subtitle = "导入到当前学期：${currentSemester?.name ?: "默认学期"}",
                        onClick = {
                            importLauncher.launch(
                                arrayOf(
                                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                    "application/vnd.ms-excel"
                                )
                            )
                        }
                    )
                    TextButton(onClick = { showImportHelp = !showImportHelp }) {
                        Text(if (showImportHelp) "收起导入说明" else "查看导入说明")
                    }
                    if (showImportHelp) {
                        Text(
                            text = "推荐表头顺序：学期、科目、考试名称、时间、分数、满分、分类、班排、年排、区排、反思。若未提供学期列，将默认导入到当前所选学期。导出文件同样按一行一条成绩记录组织。完全相同的成绩记录会在导入时自动跳过，避免重复入库。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            GlassCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp), contentPadding = 14.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    StudySectionHeader(title = "账号与数据")
                    StudySettingRow(
                        icon = Icons.Default.Person,
                        title = "多用户模式",
                        subtitle = "为不同使用者分别管理成绩、科目与学期",
                        trailing = {
                            Switch(
                                checked = userPrefs.multiUserEnabled,
                                onCheckedChange = { userManagerViewModel.setMultiUserEnabled(it) }
                            )
                        }
                    )
                    if (userPrefs.multiUserEnabled) {
                        users.forEach { user ->
                            val isCurrent = user.id == userPrefs.currentUserId
                            StudySettingRow(
                                icon = Icons.Default.Person,
                                title = if (isCurrent) "${user.name}（当前）" else user.name,
                                subtitle = if (isCurrent) "当前活跃用户" else "点击切换到该用户",
                                onClick = { userManagerViewModel.setCurrentUser(user.id) },
                                trailing = {
                                    Row {
                                        StudyCircleIconButton(
                                            icon = Icons.Default.Edit,
                                            contentDescription = "编辑用户",
                                            onClick = {
                                                editingUser = user
                                                userNameInput = user.name
                                                showUserDialog = true
                                            },
                                            size = 32,
                                            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
                                            contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        StudyCircleIconButton(
                                            icon = Icons.Default.Delete,
                                            contentDescription = "删除用户",
                                            onClick = { if (users.size > 1) userManagerViewModel.deleteUser(user) },
                                            size = 32,
                                            enabled = users.size > 1,
                                            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
                                            contentColor = if (users.size > 1) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.outline
                                        )
                                    }
                                }
                            )
                        }
                        Button(
                            onClick = {
                                editingUser = null
                                userNameInput = ""
                                showUserDialog = true
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("添加用户")
                        }
                    }
                }
            }

            GlassCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(22.dp), contentPadding = 14.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    StudySectionHeader(title = "关于")
                    StudySettingRow(
                        icon = Icons.Default.Info,
                        title = "应用信息",
                        subtitle = "学迹（StudyTrack）本地成绩记录与分析应用"
                    )
                    StudySettingRow(
                        icon = Icons.Default.Info,
                        title = "当前版本",
                        subtitle = versionName
                    )
                    StudySettingRow(
                        icon = Icons.Default.Person,
                        title = "作者主页",
                        subtitle = "酷安@在摆烂中沉沦",
                        onClick = {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.coolapk.com/u/24128753")))
                        },
                        trailing = {
                            Icon(
                                imageVector = Icons.Default.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    )
                    StudySettingRow(
                        icon = Icons.Default.Storage,
                        title = "捐赠作者",
                        subtitle = "扫码支持作者继续维护",
                        onClick = { navController.navigate(Screen.Donate.route) },
                        trailing = {
                            Icon(
                                imageVector = Icons.Default.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun ThemeStyleCard(
    title: String,
    description: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .studyPressable(
                shape = RoundedCornerShape(18.dp),
                onClick = onClick
            ),
        shape = RoundedCornerShape(18.dp),
        color = if (selected) {
            MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
        } else {
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.75f)
        }
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = if (selected) "当前已启用" else "点击切换",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun SemesterRow(
    semester: Semester,
    selected: Boolean,
    onClick: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .studyPressable(
                shape = RoundedCornerShape(16.dp),
                onClick = onClick
            ),
        shape = RoundedCornerShape(16.dp),
        color = if (selected) {
            MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
        } else {
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f)
        }
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = semester.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    text = if (selected) "当前学期" else "点击切换到该学期",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = if (selected) "使用中" else "切换",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.primary
                )
                StudyCircleIconButton(
                    icon = Icons.Default.Edit,
                    contentDescription = "重命名学期",
                    onClick = onEdit,
                    size = 32,
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
                    contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                )
                StudyCircleIconButton(
                    icon = Icons.Default.Delete,
                    contentDescription = "删除学期",
                    onClick = onDelete,
                    size = 32,
                    enabled = !selected,
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f),
                    contentColor = if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.error
                )
            }
        }
    }
}
