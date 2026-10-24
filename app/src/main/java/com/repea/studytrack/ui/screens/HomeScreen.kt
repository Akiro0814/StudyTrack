package com.repea.studytrack.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import androidx.navigation.NavGraph.Companion.findStartDestination
import com.repea.studytrack.ui.components.GlassCard
import com.repea.studytrack.ui.components.GlassDropdownMenu
import com.repea.studytrack.ui.components.PieChartData
import com.repea.studytrack.ui.components.SimplePieChart
import com.repea.studytrack.ui.components.StudyHeroCard
import com.repea.studytrack.ui.components.StudyCircleIconButton
import com.repea.studytrack.ui.components.StudyMetricCard
import com.repea.studytrack.ui.components.StudySectionHeader
import com.repea.studytrack.ui.components.StudyTextField
import com.repea.studytrack.ui.components.studyPressable
import com.repea.studytrack.ui.navigation.Screen
import com.repea.studytrack.utils.GradeCalculator
import com.repea.studytrack.viewmodel.AnalysisViewModel
import com.repea.studytrack.viewmodel.ExamViewModel
import com.repea.studytrack.viewmodel.UserManagerViewModel
import com.repea.studytrack.viewmodel.UserPreferencesViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun HomeScreen(
    navController: NavController,
    analysisViewModel: AnalysisViewModel = hiltViewModel(),
    examViewModel: ExamViewModel = hiltViewModel(),
    userManagerViewModel: UserManagerViewModel = hiltViewModel(),
    prefsViewModel: UserPreferencesViewModel = hiltViewModel()
) {
    val recentExams by examViewModel.allRecords.collectAsState()
    val subjects by examViewModel.subjects.collectAsState()
    val userPrefs by userManagerViewModel.prefs.collectAsState()
    val users by userManagerViewModel.users.collectAsState()
    val semesters by userManagerViewModel.semesters.collectAsState()
    val gradePrefs by prefsViewModel.preferences.collectAsState()

    val currentUser = remember(users, userPrefs.currentUserId) {
        users.firstOrNull { it.id == userPrefs.currentUserId } ?: users.firstOrNull()
    }
    val currentSemester = remember(semesters, userPrefs.currentSemesterId) {
        semesters.firstOrNull { it.id == userPrefs.currentSemesterId } ?: semesters.firstOrNull()
    }
    val latestExam = remember(recentExams) { recentExams.maxByOrNull { it.exam.examDate } }
    val visibleRecentExams = remember(recentExams) {
        recentExams.sortedByDescending { it.exam.examDate }.take(5)
    }
    val avgScore = remember(recentExams) {
        if (recentExams.isEmpty()) 0.0 else recentExams.map { it.exam.score }.average()
    }
    val excellentCount = remember(recentExams, gradePrefs) {
        recentExams.count { item ->
            GradeCalculator.calculateGradeCustom(
                score = item.exam.score,
                fullScore = item.subject.fullScore,
                prefs = gradePrefs
            ) == "A"
        }
    }
    val pieData = remember(recentExams, gradePrefs) {
        var countA = 0
        var countB = 0
        var countC = 0
        var countD = 0
        recentExams.forEach { record ->
            when (
                GradeCalculator.calculateGradeCustom(
                    score = record.exam.score,
                    fullScore = record.subject.fullScore,
                    prefs = gradePrefs
                )
            ) {
                "A" -> countA++
                "B" -> countB++
                "C" -> countC++
                else -> countD++
            }
        }
        listOf(
            PieChartData("A", countA.toFloat(), Color(0xFF5C7CFA)),
            PieChartData("B", countB.toFloat(), Color(0xFF8EA4FF)),
            PieChartData("C", countC.toFloat(), Color(0xFFB8C6FF)),
            PieChartData("D", countD.toFloat(), Color(0xFFFF8C8A))
        ).filter { it.value > 0 }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .navigationBarsPadding()
    ) {
        HomeTopBar(
            navController = navController,
            currentUserName = currentUser?.name ?: "同学",
            currentSemesterName = currentSemester?.name ?: "默认学期",
            userManagerViewModel = userManagerViewModel,
            userPrefsEnabled = userPrefs.multiUserEnabled,
            users = users
        )
        Spacer(modifier = Modifier.height(16.dp))
        StudyHeroCard(
            title = "总平均分",
            value = if (recentExams.isEmpty()) "--" else String.format("%.1f", avgScore),
            badge = latestExam?.let {
                val fullScore = if (it.subject.fullScore % 1.0 == 0.0) {
                    it.subject.fullScore.toInt().toString()
                } else {
                    String.format("%.1f", it.subject.fullScore)
                }
                "${it.exam.score}/${fullScore}"
            } ?: "暂无成绩",
            subtitle = buildString {
                append(currentSemester?.name ?: "默认学期")
                append(" · ")
                append("共记录 ")
                append(recentExams.size)
                append(" 次考试")
                if (subjects.isNotEmpty()) {
                    append(" · ")
                    append(subjects.size)
                    append(" 门科目")
                }
            },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(14.dp))
        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
            if (maxWidth < 360.dp) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        StudyMetricCard(
                            title = "最高分",
                            value = latestExam?.exam?.score?.let { String.format("%.0f", it) } ?: "--",
                            note = "最近一次记录",
                            modifier = Modifier.weight(1f),
                            accent = Color(0xFF5C7CFA)
                        )
                        StudyMetricCard(
                            title = "优秀率",
                            value = if (recentExams.isEmpty()) "--" else "${(excellentCount * 100 / recentExams.size)}%",
                            note = "A 等级占比",
                            modifier = Modifier.weight(1f),
                            accent = Color(0xFF24B46B)
                        )
                    }
                    StudyMetricCard(
                        title = "科目数",
                        value = subjects.size.toString(),
                        note = "已录入科目",
                        modifier = Modifier.fillMaxWidth(),
                        accent = Color(0xFFFFA63D)
                    )
                }
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    StudyMetricCard(
                        title = "最高分",
                        value = latestExam?.exam?.score?.let { String.format("%.0f", it) } ?: "--",
                        note = "最近一次记录",
                        modifier = Modifier.weight(1f),
                        accent = Color(0xFF5C7CFA)
                    )
                    StudyMetricCard(
                        title = "优秀率",
                        value = if (recentExams.isEmpty()) "--" else "${(excellentCount * 100 / recentExams.size)}%",
                        note = "A 等级占比",
                        modifier = Modifier.weight(1f),
                        accent = Color(0xFF24B46B)
                    )
                    StudyMetricCard(
                        title = "科目数",
                        value = subjects.size.toString(),
                        note = "已录入科目",
                        modifier = Modifier.weight(1f),
                        accent = Color(0xFFFFA63D)
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(20.dp))
        StudySectionHeader(
            title = "最近成绩",
            actionText = if (recentExams.isNotEmpty()) "查看全部" else null,
            onActionClick = {
                navController.navigate(Screen.ExamList.route) {
                    popUpTo(navController.graph.findStartDestination().id) {
                        saveState = true
                    }
                    launchSingleTop = true
                    restoreState = true
                }
            }
        )
        Spacer(modifier = Modifier.height(10.dp))
        if (recentExams.isEmpty()) {
            GlassCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "还没有成绩记录",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "先添加一条成绩，首页会自动生成统计卡片与趋势分析。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            visibleRecentExams.forEach { record ->
                    GlassCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 10.dp),
                        shape = RoundedCornerShape(20.dp),
                        contentPadding = 12.dp
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(42.dp)
                                    .clip(RoundedCornerShape(14.dp))
                                    .background(MaterialTheme.colorScheme.surfaceVariant),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = record.subject.name.take(1),
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = record.subject.name,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Text(
                                    text = "${record.exam.examName} · ${
                                        SimpleDateFormat("yyyy/MM/dd", Locale.ROOT).format(Date(record.exam.examDate))
                                    }",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(
                                    text = if (record.exam.score % 1.0 == 0.0) {
                                        record.exam.score.toInt().toString()
                                    } else {
                                        String.format("%.1f", record.exam.score)
                                    },
                                    style = MaterialTheme.typography.titleLarge,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = GradeCalculator.calculateGradeCustom(
                                        score = record.exam.score,
                                        fullScore = record.subject.fullScore,
                                        prefs = gradePrefs
                                    ),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                    }
                }
        }
        if (pieData.isNotEmpty()) {
            Spacer(modifier = Modifier.height(8.dp))
            StudySectionHeader(title = "成绩概览")
            Spacer(modifier = Modifier.height(10.dp))
            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(20.dp),
                contentPadding = 18.dp
            ) {
                BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                    val compactLayout = maxWidth < 360.dp
                    if (compactLayout) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(14.dp)
                        ) {
                            SimplePieChart(
                                data = pieData,
                                modifier = Modifier.size(148.dp),
                                textColor = MaterialTheme.colorScheme.onSurface
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                pieData.forEach { item ->
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(10.dp)
                                                .clip(CircleShape)
                                                .background(item.color)
                                        )
                                        Text(
                                            text = "${item.label} 等级 ${item.value.toInt()} 次",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                }
                            }
                        }
                    } else {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            SimplePieChart(
                                data = pieData,
                                modifier = Modifier.size(148.dp),
                                textColor = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.size(12.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                pieData.forEach { item ->
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Box(
                                            modifier = Modifier
                                                .size(10.dp)
                                                .clip(CircleShape)
                                                .background(item.color)
                                        )
                                        Text(
                                            text = "${item.label} 等级 ${item.value.toInt()} 次",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        StudySectionHeader(title = "快捷入口")
        Spacer(modifier = Modifier.height(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            QuickEntryCard(
                title = "录入成绩",
                subtitle = "快速添加单次成绩",
                modifier = Modifier.weight(1f),
                onClick = { navController.navigate(Screen.AddExam.route) }
            )
            QuickEntryCard(
                title = "管理科目",
                subtitle = "查看并编辑科目",
                modifier = Modifier.weight(1f),
                onClick = {
                    navController.navigate(Screen.SubjectList.route) {
                        popUpTo(navController.graph.findStartDestination().id) {
                            saveState = true
                        }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            )
        }
        Spacer(modifier = Modifier.height(28.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeTopBar(
    navController: NavController,
    currentUserName: String,
    currentSemesterName: String,
    userManagerViewModel: UserManagerViewModel,
    userPrefsEnabled: Boolean,
    users: List<com.repea.studytrack.data.local.entity.UserProfile>
) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val compactLayout = maxWidth < 360.dp
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(if (compactLayout) 6.dp else 4.dp)
            ) {
                Text(
                    text = "早上好，同学",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "学习成绩管理",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = currentSemesterName,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (userPrefsEnabled && users.isNotEmpty()) {
                    var menuExpanded by remember { mutableStateOf(false) }
                    ExposedDropdownMenuBox(
                        expanded = menuExpanded,
                        onExpandedChange = { menuExpanded = it }
                    ) {
                        Surface(
                            modifier = Modifier
                                .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable)
                                .fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.56f)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(
                                    modifier = Modifier.weight(1f),
                                    verticalArrangement = Arrangement.spacedBy(2.dp)
                                ) {
                                    Text(
                                        text = "当前用户",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = currentUserName,
                                        style = MaterialTheme.typography.titleSmall,
                                        color = MaterialTheme.colorScheme.onSurface,
                                        fontWeight = FontWeight.SemiBold,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                                ExposedDropdownMenuDefaults.TrailingIcon(expanded = menuExpanded)
                            }
                        }
                        GlassDropdownMenu(
                            expanded = menuExpanded,
                            onDismissRequest = { menuExpanded = false }
                        ) {
                            users.forEach { user ->
                                DropdownMenuItem(
                                    text = { Text(user.name) },
                                    onClick = {
                                        userManagerViewModel.setCurrentUser(user.id)
                                        menuExpanded = false
                                    }
                                )
                            }
                        }
                    }
                } else {
                    Text(
                        text = currentUserName,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StudyCircleIconButton(
                    icon = Icons.Default.NotificationsNone,
                    contentDescription = "通知",
                    onClick = {
                        navController.navigate(Screen.Settings.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    size = if (compactLayout) 36 else 40
                )
                Box(
                    modifier = Modifier
                        .size(if (compactLayout) 36.dp else 40.dp)
                        .background(MaterialTheme.colorScheme.primary, CircleShape)
                        .studyPressable(
                            shape = CircleShape,
                            pressedScale = 0.94f,
                            onClick = {
                                navController.navigate(Screen.Settings.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        val initial = currentUserName.trim().firstOrNull()?.toString() ?: "我"
                        Text(
                            text = initial,
                            color = MaterialTheme.colorScheme.onPrimary,
                            style = if (compactLayout) {
                                MaterialTheme.typography.titleMedium
                            } else {
                                MaterialTheme.typography.titleLarge
                            },
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickEntryCard(
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    GlassCard(
        modifier = modifier
            .studyPressable(
                shape = RoundedCornerShape(20.dp),
                onClick = onClick
            ),
        shape = RoundedCornerShape(20.dp),
        contentPadding = 14.dp
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }
    }
}
