package com.repea.studytrack.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.BasicAlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import com.repea.studytrack.data.local.entity.ExamType
import com.repea.studytrack.data.local.entity.Subject
import com.repea.studytrack.repository.AppThemeStyle
import com.repea.studytrack.ui.components.GlassButton
import com.repea.studytrack.ui.components.GlassCard
import com.repea.studytrack.ui.components.GlassDropdownMenu
import com.repea.studytrack.ui.components.StudyCapsuleButton
import com.repea.studytrack.ui.components.StudyHeroCard
import com.repea.studytrack.ui.components.StudySectionHeader
import com.repea.studytrack.ui.components.StudyTextField
import com.repea.studytrack.ui.theme.LocalAppThemeStyle
import com.repea.studytrack.viewmodel.ExamViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private data class SubjectEntryUiState(
    val id: Long,
    val subject: Subject? = null,
    val score: String = "",
    val classRank: String = "",
    val gradeRank: String = "",
    val districtRank: String = ""
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BatchAddExamScreen(
    navController: NavController,
    viewModel: ExamViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val subjects by viewModel.subjects.collectAsState()
    val allRecords by viewModel.allRecords.collectAsState()

    var examName by remember { mutableStateOf("") }
    var selectedExamType by remember { mutableStateOf(ExamType.MONTHLY) }
    var examTypeExpanded by remember { mutableStateOf(false) }

    var examDate by remember { mutableStateOf(System.currentTimeMillis()) }
    var showDatePicker by remember { mutableStateOf(false) }
    val datePickerState = rememberDatePickerState(initialSelectedDateMillis = examDate)

    var entries by remember { mutableStateOf(listOf(SubjectEntryUiState(id = 0L))) }
    var nextId by remember { mutableStateOf(1L) }

    var errorMessage by remember { mutableStateOf<String?>(null) }

    if (showDatePicker) {
        BasicAlertDialog(onDismissRequest = { showDatePicker = false }) {
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("选择考试日期", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
                    DatePicker(
                        state = datePickerState,
                        modifier = Modifier.scale(0.96f)
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextButton(onClick = { showDatePicker = false }) {
                            Text("取消")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        TextButton(
                            onClick = {
                                datePickerState.selectedDateMillis?.let { examDate = it }
                                showDatePicker = false
                            }
                        ) {
                            Text("确定")
                        }
                    }
                }
            }
        }
    }

    Scaffold(containerColor = Color.Transparent) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp, vertical = 10.dp)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "批量添加成绩",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "一次录入同场考试下的多门学科成绩",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            StudyHeroCard(
                title = "批量录入",
                value = entries.size.toString(),
                badge = selectedExamType.label,
                subtitle = "当前待录入 ${entries.count { it.subject != null && it.score.isNotBlank() }} 门科目",
                modifier = Modifier.fillMaxWidth()
            )

            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(22.dp),
                contentPadding = 16.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    StudySectionHeader(title = "考试信息")
                    StudyTextField(
                        value = examName,
                        onValueChange = { examName = it },
                        label = "考试主题"
                    )

                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.32f),
                        onClick = { showDatePicker = true }
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(
                                    text = "考试日期",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(Date(examDate)),
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                            Icon(
                                imageVector = Icons.Default.DateRange,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                    StudySectionHeader(title = "考试类型")
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        ExamType.values().forEach { type ->
                            StudyCapsuleButton(
                                selected = selectedExamType == type,
                                text = type.label,
                                onClick = { selectedExamType = type }
                            )
                        }
                    }
                }
            }

            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(22.dp),
                contentPadding = 16.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "科目成绩列表",
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            fontWeight = FontWeight.SemiBold
                        )
                        Surface(
                            onClick = {
                                entries = entries + SubjectEntryUiState(id = nextId++)
                            },
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.primary
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Add,
                                    contentDescription = "添加科目",
                                    tint = MaterialTheme.colorScheme.onPrimary,
                                    modifier = Modifier.size(18.dp)
                                )
                                Text("添加", color = MaterialTheme.colorScheme.onPrimary)
                            }
                        }
                    }

                    if (entries.isEmpty()) {
                        Text(
                            text = "请点击右上角 + 按钮添加科目。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                        )
                    } else {
                        entries.forEach { entry ->
                            SubjectEntryCard(
                                entry = entry,
                                subjects = subjects,
                                onChange = { updated ->
                                    entries = entries.map { if (it.id == updated.id) updated else it }
                                },
                                onRemove = {
                                    entries = entries.filterNot { it.id == entry.id }
                                }
                            )
                        }
                    }
                }
            }

            if (errorMessage != null) {
                Text(
                    text = errorMessage.orEmpty(),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            GlassButton(
                onClick = {
                    errorMessage = null

                    if (examName.isBlank()) {
                        errorMessage = "请先填写考试主题。"
                        return@GlassButton
                    }

                    val selectedSubjectIds = entries.mapNotNull { it.subject?.id }
                    if (selectedSubjectIds.size != selectedSubjectIds.distinct().size) {
                        errorMessage = "同一场考试中不能重复选择同一科目。"
                        return@GlassButton
                    }

                    val validEntries = entries.mapNotNull { e ->
                        val subject = e.subject ?: return@mapNotNull null
                        val scoreVal = e.score.toDoubleOrNull() ?: return@mapNotNull null
                        if (scoreVal > subject.fullScore) return@mapNotNull null
                        Triple(subject, scoreVal, e)
                    }

                    if (validEntries.isEmpty()) {
                        errorMessage = "请至少为一个科目选择科目并填写有效分数。"
                        return@GlassButton
                    }

                    val duplicatedEntries = validEntries.filter { (subject, scoreVal, _) ->
                        allRecords.any {
                            it.exam.subjectId == subject.id &&
                                it.exam.examName == examName &&
                                it.exam.examDate == examDate &&
                                it.exam.score == scoreVal
                        }
                    }
                    val entriesToSave = validEntries.filterNot { candidate ->
                        duplicatedEntries.any { duplicated -> duplicated.first.id == candidate.first.id }
                    }

                    if (entriesToSave.isEmpty()) {
                        errorMessage = "待保存记录均已存在，未重复写入。"
                        return@GlassButton
                    }

                    entriesToSave.forEach { (subject, scoreVal, e) ->
                        viewModel.addRecord(
                            subjectId = subject.id,
                            examName = examName,
                            examDate = examDate,
                            score = scoreVal,
                            examType = selectedExamType,
                            classRank = e.classRank.toIntOrNull(),
                            gradeRank = e.gradeRank.toIntOrNull(),
                            districtRank = e.districtRank.toIntOrNull(),
                            reflection = null,
                            imageUri = null
                        )
                    }

                    val toastMessage = if (duplicatedEntries.isEmpty()) {
                        "已保存 ${entriesToSave.size} 条成绩"
                    } else {
                        "已保存 ${entriesToSave.size} 条，跳过重复 ${duplicatedEntries.size} 条"
                    }
                    android.widget.Toast.makeText(context, toastMessage, android.widget.Toast.LENGTH_LONG).show()
                    navController.popBackStack()
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp)
            ) {
                val themeStyle = LocalAppThemeStyle.current
                Text(
                    text = "保存全部成绩",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp),
                    color = if (themeStyle == AppThemeStyle.LIQUID_GLASS) {
                        MaterialTheme.colorScheme.onSurface
                    } else {
                        MaterialTheme.colorScheme.onPrimary
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SubjectEntryCard(
    entry: SubjectEntryUiState,
    subjects: List<Subject>,
    onChange: (SubjectEntryUiState) -> Unit,
    onRemove: () -> Unit
) {
    var subjectExpanded by remember(entry.id) { mutableStateOf(false) }

    GlassCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        contentPadding = 14.dp
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = entry.subject?.name ?: "未选择科目",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold
                )
                if (subjects.size > 1) {
                    IconButton(onClick = onRemove) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "移除此科目",
                            tint = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }

            if (subjects.isEmpty()) {
                Text(
                    text = "当前暂无科目，请先在「科目」页面添加科目。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
            } else {
                ExposedDropdownMenuBox(
                    expanded = subjectExpanded,
                    onExpandedChange = { subjectExpanded = !subjectExpanded }
                ) {
                    StudyTextField(
                        value = entry.subject?.name ?: "",
                        onValueChange = {},
                        label = "科目",
                        readOnly = true,
                        modifier = Modifier
                            .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable)
                            .fillMaxWidth(),
                        trailing = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = subjectExpanded) }
                    )
                    GlassDropdownMenu(
                        expanded = subjectExpanded,
                        onDismissRequest = { subjectExpanded = false }
                    ) {
                        subjects.forEach { subject ->
                            DropdownMenuItem(
                                text = { Text(subject.name) },
                                onClick = {
                                    onChange(entry.copy(subject = subject))
                                    subjectExpanded = false
                                }
                            )
                        }
                    }
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StudyTextField(
                    value = entry.score,
                    onValueChange = { onChange(entry.copy(score = it)) },
                    label = "分数",
                    modifier = Modifier.weight(1f),
                    supporting = {
                        Text(
                            entry.subject?.let { "满分 ${formatBatchScore(it.fullScore)}" } ?: "请输入分数"
                        )
                    }
                )
                StudyTextField(
                    value = entry.classRank,
                    onValueChange = { onChange(entry.copy(classRank = it)) },
                    label = "班排",
                    modifier = Modifier.weight(1f)
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                StudyTextField(
                    value = entry.gradeRank,
                    onValueChange = { onChange(entry.copy(gradeRank = it)) },
                    label = "年排",
                    modifier = Modifier.weight(1f)
                )
                StudyTextField(
                    value = entry.districtRank,
                    onValueChange = { onChange(entry.copy(districtRank = it)) },
                    label = "区排",
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

private fun formatBatchScore(value: Double): String {
    return if (value % 1.0 == 0.0) {
        value.toInt().toString()
    } else {
        String.format("%.1f", value)
    }
}
