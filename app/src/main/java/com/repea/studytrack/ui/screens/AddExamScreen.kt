package com.repea.studytrack.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.EditNote
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import com.repea.studytrack.repository.AppThemeStyle
import com.repea.studytrack.ui.theme.LocalAppThemeStyle
import com.repea.studytrack.data.local.entity.ExamType
import com.repea.studytrack.data.local.entity.Subject
import com.repea.studytrack.ui.components.GlassButton
import com.repea.studytrack.ui.components.GlassCard
import com.repea.studytrack.ui.components.GlassDropdownMenu
import com.repea.studytrack.ui.components.StudyCapsuleButton
import com.repea.studytrack.ui.components.StudySectionHeader
import com.repea.studytrack.ui.components.StudyTextField
import com.repea.studytrack.viewmodel.ExamViewModel
import com.repea.studytrack.viewmodel.UserManagerViewModel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddExamScreen(
    navController: NavController,
    viewModel: ExamViewModel = hiltViewModel(),
    userManagerViewModel: UserManagerViewModel = hiltViewModel(),
    recordId: Int? = null
) {
    val context = LocalContext.current
    val themeStyle = LocalAppThemeStyle.current
    val subjects by viewModel.subjects.collectAsState()
    val allRecords by viewModel.allRecords.collectAsState()
    val userPrefs by userManagerViewModel.prefs.collectAsState()
    val semesters by userManagerViewModel.semesters.collectAsState()
    val currentSemester = remember(semesters, userPrefs.currentSemesterId) {
        semesters.firstOrNull { it.id == userPrefs.currentSemesterId } ?: semesters.firstOrNull()
    }

    var selectedSubject by remember { mutableStateOf<Subject?>(null) }
    var subjectExpanded by remember { mutableStateOf(false) }
    var examName by remember { mutableStateOf("") }
    var score by remember { mutableStateOf("") }
    var scoreError by remember { mutableStateOf<String?>(null) }
    var formError by remember { mutableStateOf<String?>(null) }
    var classRank by remember { mutableStateOf("") }
    var gradeRank by remember { mutableStateOf("") }
    var districtRank by remember { mutableStateOf("") }
    var reflection by remember { mutableStateOf("") }
    var selectedExamType by remember { mutableStateOf(ExamType.MONTHLY) }
    var examDate by remember { mutableStateOf(System.currentTimeMillis()) }
    var showDatePicker by remember { mutableStateOf(false) }

    val datePickerState = rememberDatePickerState(initialSelectedDateMillis = examDate)
    val editingRecord = remember(recordId, allRecords) {
        recordId?.let { id -> allRecords.firstOrNull { it.exam.id == id } }
    }
    var initialized by remember(recordId) { mutableStateOf(false) }

    LaunchedEffect(editingRecord) {
        if (!initialized && editingRecord != null) {
            selectedSubject = editingRecord.subject
            examName = editingRecord.exam.examName
            score = formatNumber(editingRecord.exam.score)
            classRank = editingRecord.exam.classRank?.toString() ?: ""
            gradeRank = editingRecord.exam.gradeRank?.toString() ?: ""
            districtRank = editingRecord.exam.districtRank?.toString() ?: ""
            reflection = editingRecord.exam.reflection ?: ""
            selectedExamType = ExamType.fromLabel(editingRecord.exam.examType)
            examDate = editingRecord.exam.examDate
            datePickerState.selectedDateMillis = editingRecord.exam.examDate
            initialized = true
        }
    }

    LaunchedEffect(showDatePicker) {
        if (showDatePicker) {
            datePickerState.selectedDateMillis = examDate
        }
    }

    if (showDatePicker) {
        BasicAlertDialog(onDismissRequest = { showDatePicker = false }) {
            GlassCard(modifier = Modifier.fillMaxWidth(), shape = androidx.compose.foundation.shape.RoundedCornerShape(24.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "选择考试日期",
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontWeight = FontWeight.Bold
                    )
                    DatePicker(
                        state = datePickerState,
                        modifier = Modifier.scale(0.96f)
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextButton(onClick = { showDatePicker = false }) {
                            Text("取消")
                        }
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

    Scaffold(
        containerColor = Color.Transparent
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 10.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    shape = androidx.compose.foundation.shape.CircleShape,
                    color = MaterialTheme.colorScheme.surface,
                    onClick = { navController.popBackStack() }
                ) {
                    Box(modifier = Modifier.padding(10.dp), contentAlignment = Alignment.Center) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "返回",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
                Spacer(modifier = Modifier.weight(1f))
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = if (recordId == null) "添加成绩记录" else "编辑成绩记录",
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "已录入成绩后将自动参与分析与首页统计",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "当前学期：${currentSemester?.name ?: "默认学期"}",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(22.dp),
                contentPadding = 18.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "输入分数",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = if (score.isBlank()) "--" else score,
                        style = MaterialTheme.typography.headlineLarge,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = selectedSubject?.let { "/ ${formatNumber(it.fullScore)}" } ?: "/ 100",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(22.dp),
                contentPadding = 16.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    StudySectionHeader(title = "选择科目")
                    ExposedDropdownMenuBox(
                        expanded = subjectExpanded,
                        onExpandedChange = { subjectExpanded = it }
                    ) {
                        StudyTextField(
                            value = selectedSubject?.name ?: "",
                            onValueChange = {},
                            label = "科目",
                            modifier = Modifier
                                .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable)
                                .fillMaxWidth(),
                            readOnly = true,
                            trailing = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = subjectExpanded) },
                            supporting = {
                                Text(if (selectedSubject == null) "请选择录入的科目" else "当前满分 ${formatNumber(selectedSubject!!.fullScore)}")
                            }
                        )
                        GlassDropdownMenu(
                            expanded = subjectExpanded,
                            onDismissRequest = { subjectExpanded = false }
                        ) {
                            subjects.forEach { subject ->
                                DropdownMenuItem(
                                    text = { Text(subject.name) },
                                    onClick = {
                                        selectedSubject = subject
                                        subjectExpanded = false
                                        val value = score.toDoubleOrNull()
                                        scoreError = if (value != null && value > subject.fullScore) {
                                            "分数不能超过满分 ${formatNumber(subject.fullScore)}"
                                        } else {
                                            null
                                        }
                                    }
                                )
                            }
                        }
                    }
                    StudySectionHeader(title = "选择科型")
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
                    StudySectionHeader(title = "考试类型")
                    StudyTextField(
                        value = examName,
                        onValueChange = { examName = it },
                        label = "考试名称"
                    )
                    DatePickerField(
                        label = "考试日期",
                        value = SimpleDateFormat("yyyy年MM月dd日", Locale.ROOT).format(Date(examDate)),
                        onClick = { showDatePicker = true }
                    )
                }
            }
            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(22.dp),
                contentPadding = 16.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    StudySectionHeader(title = "考试成绩")
                    StudyTextField(
                        value = score,
                        onValueChange = {
                            score = it
                            formError = null
                            val value = it.toDoubleOrNull()
                            scoreError = when {
                                value == null && it.isNotBlank() -> "请输入有效数字"
                                value != null && selectedSubject != null && value > selectedSubject!!.fullScore ->
                                    "分数不能超过满分 ${formatNumber(selectedSubject!!.fullScore)}"
                                else -> null
                            }
                        },
                        label = "成绩分数",
                        isError = scoreError != null,
                        supporting = {
                            Text(scoreError ?: "支持输入整数或小数")
                        }
                    )
                    StudySectionHeader(title = "选择科型")
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        StudyTextField(
                            value = classRank,
                            onValueChange = { classRank = it.filter { ch -> ch.isDigit() } },
                            label = "班排",
                            modifier = Modifier.weight(1f)
                        )
                        StudyTextField(
                            value = gradeRank,
                            onValueChange = { gradeRank = it.filter { ch -> ch.isDigit() } },
                            label = "年排",
                            modifier = Modifier.weight(1f)
                        )
                        StudyTextField(
                            value = districtRank,
                            onValueChange = { districtRank = it.filter { ch -> ch.isDigit() } },
                            label = "区排",
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
            GlassCard(
                modifier = Modifier.fillMaxWidth(),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(22.dp),
                contentPadding = 16.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    StudySectionHeader(title = "备注信息")
                    StudyTextField(
                        value = reflection,
                        onValueChange = { reflection = it },
                        label = "备注",
                        singleLine = false,
                        trailing = {
                            Icon(
                                imageVector = Icons.Default.EditNote,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        },
                        supporting = {
                            Text("可填写失分原因、复盘结论或下次改进计划")
                        }
                    )
                }
            }
            GlassButton(
                onClick = {
                    val scoreVal = score.toDoubleOrNull()
                    formError = null
                    if (selectedSubject == null) {
                        scoreError = "请先选择科目"
                        return@GlassButton
                    }
                    if (scoreVal == null) {
                        scoreError = "请输入有效分数"
                        return@GlassButton
                    }
                    if (scoreVal > selectedSubject!!.fullScore) {
                        scoreError = "分数不能超过满分"
                        return@GlassButton
                    }
                    val finalExamName = examName.ifBlank { selectedExamType.label }
                    val duplicateRecord = allRecords.firstOrNull {
                        it.exam.id != (editingRecord?.exam?.id ?: -1) &&
                            it.exam.subjectId == selectedSubject!!.id &&
                            it.exam.examName == finalExamName &&
                            it.exam.examDate == examDate &&
                            it.exam.score == scoreVal
                    }
                    if (duplicateRecord != null) {
                        formError = "检测到相同成绩记录，已拦截重复保存。"
                        return@GlassButton
                    }
                    if (recordId != null && editingRecord != null) {
                        viewModel.updateRecord(
                            editingRecord.exam.copy(
                                subjectId = selectedSubject!!.id,
                                examName = finalExamName,
                                examDate = examDate,
                                score = scoreVal,
                                examType = selectedExamType.label,
                                classRank = classRank.toIntOrNull(),
                                gradeRank = gradeRank.toIntOrNull(),
                                districtRank = districtRank.toIntOrNull(),
                                reflection = reflection
                            )
                        )
                    } else {
                        viewModel.addRecord(
                            subjectId = selectedSubject!!.id,
                            examName = finalExamName,
                            examDate = examDate,
                            score = scoreVal,
                            examType = selectedExamType,
                            classRank = classRank.toIntOrNull(),
                            gradeRank = gradeRank.toIntOrNull(),
                            districtRank = districtRank.toIntOrNull(),
                            reflection = reflection,
                            imageUri = null
                        )
                    }
                    android.widget.Toast.makeText(
                        context,
                        if (recordId == null) "成绩已保存" else "修改已保存",
                        android.widget.Toast.LENGTH_SHORT
                    ).show()
                    navController.popBackStack()
                },
                modifier = Modifier.fillMaxWidth(),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(18.dp)
            ) {
                Text(
                    text = if (recordId == null) "保存记录" else "保存修改",
                    color = if (themeStyle == AppThemeStyle.PURE_WHITE) {
                        MaterialTheme.colorScheme.onPrimary
                    } else {
                        MaterialTheme.colorScheme.onSurface
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
            if (formError != null) {
                Text(
                    text = formError.orEmpty(),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

private fun formatNumber(value: Double): String {
    return if (value % 1.0 == 0.0) {
        value.toInt().toString()
    } else {
        String.format("%.1f", value)
    }
}

@Composable
private fun DatePickerField(
    label: String,
    value: String,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth(),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.32f),
        onClick = onClick
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
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = value,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Icon(
                imageVector = Icons.Default.DateRange,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }
    }
}
