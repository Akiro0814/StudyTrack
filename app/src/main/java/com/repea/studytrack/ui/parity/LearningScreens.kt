@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
package com.repea.studytrack.ui.parity

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.Orientation
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.gestures.rememberDraggableState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.*
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.utils.GradeCalculator
import com.repea.studytrack.viewmodel.PlatformViewModel
import kotlin.math.roundToInt

@Composable fun HomeScreen(state: PlatformState,onRecord: (String) -> Unit,onNavigate: (String) -> Unit,onEdit: (ExamRecord) -> Unit,vm: PlatformViewModel) {
    StudyPage {
        Row(Modifier.fillMaxWidth(),horizontalArrangement = Arrangement.spacedBy(16.dp),verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.clickable { onNavigate("profile") }.testTag("home.avatar")) { StudyAvatar(state.user?.name.orEmpty(),state.user?.avatarUri) }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { Text("今天，也向前一点。",style = MaterialTheme.typography.bodyMedium,color = MaterialTheme.colorScheme.onSurfaceVariant); Text(state.user?.name ?: "同学",style = MaterialTheme.typography.headlineLarge) }
        }
        StudyPanel {
            StudyRow("学习进行时",state.semester?.name ?: "学期",onClick = { onNavigate("semesters") })
            val latest = state.records.firstOrNull()
            if(latest == null) {
                Text("你的进步，\n从第一次记录开始。",style = MaterialTheme.typography.headlineMedium)
                Text("留下分数，也留下努力的轨迹。",color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else Row(Modifier.fillMaxWidth().clickable { onEdit(latest.exam) },verticalAlignment = Alignment.CenterVertically,horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(Modifier.weight(1f),verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("最近一次 · ${latest.subject.name}",color = MaterialTheme.colorScheme.onSurfaceVariant,style = MaterialTheme.typography.bodyMedium)
                    Text(formatScore(latest.exam.score),style = MaterialTheme.typography.headlineLarge)
                    Text("/ ${formatScore(latest.subject.fullScore)}",style = MaterialTheme.typography.bodyMedium,color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("${latest.exam.examName.ifBlank { latest.exam.examType }} · ${latest.exam.calendarDate()}",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if(LocalDensity.current.fontScale < 1.5f) {
                    val accent = MaterialTheme.colorScheme.primary
                    Box(Modifier.size(64.dp),contentAlignment = Alignment.Center) {
                        Canvas(Modifier.fillMaxSize()) { drawArc(accent.copy(alpha = 0.12f),0f,360f,false,style = Stroke(7.dp.toPx())); drawArc(accent,-90f,(latest.exam.score/latest.subject.fullScore*360).toFloat().coerceIn(0f,360f),false,style = Stroke(7.dp.toPx(),cap = StrokeCap.Round)) }
                        Text(GradeCalculator.calculateGradeCustom(latest.exam.score,latest.subject.fullScore),style = MaterialTheme.typography.titleLarge)
                    }
                }
            }
            StudyPrimary("＋ 添加成绩",{ onRecord("single") },enabled = !vm.busy,tag = "home.add")
            TextButton(onClick = { onRecord("batch") },Modifier.fillMaxWidth()) { Text("一次考试，多科录入") }
        }
        StudyHeading("本学期","${state.subjects.size} 科 · ${state.records.size} 次记录")
        for(group in state.analysis(false)) StudyPanel { StudyHeading(group.subject.name,"满分 ${formatScore(group.subject.fullScore)}"); StudySummary(group) }
        StudyHeading("最近的足迹","轻点编辑 · 左滑删除")
        if(state.records.isEmpty()) StudyEmpty("把努力留在这里","每场考试都是一个新的起点。","记录第一场考试") { onRecord("single") }
        else StudyPanel {
            for(row in state.records.take(5)) ExamRow(row,onEdit = { onEdit(row.exam) },onDelete = { vm.delete(row.exam) })
            TextButton(onClick = { onNavigate("records") },Modifier.fillMaxWidth()) { Text("查看全部 ${state.records.size} 条成绩") }
        }
    }
}
@Composable fun StudySummary(group: SubjectHistory) {
    val values = listOf("平均分" to (group.average?.let { String.format(java.util.Locale.ROOT,"%.1f",it) } ?: "—"),"最高分" to (group.maximum?.let(::formatScore) ?: "—"),"优秀率" to (group.excellence?.let { "$it%" } ?: "—"))
    @Composable fun metric(pair: Pair<String,String>) { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { Text(pair.first,style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant); Text(pair.second,style = MaterialTheme.typography.headlineSmall) } }
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        if(maxWidth < 270.dp || LocalDensity.current.fontScale > 1.5f) Column(verticalArrangement = Arrangement.spacedBy(16.dp)) { values.forEach { metric(it) } }
        else Row(Modifier.fillMaxWidth(),horizontalArrangement = Arrangement.SpaceBetween) { values.forEach { metric(it) } }
    }
}
@Composable fun ExamRow(row: ExamWithSubject,onEdit: () -> Unit,onDelete: () -> Unit) {
    val density = LocalDensity.current; val maxOffset = with(density) { 80.dp.toPx() }
    var offset by remember(row.exam.id) { mutableFloatStateOf(0f) }
    val animated by animateFloatAsState(offset,label = "swipe-record")
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))) {
        if(offset < -1) IconButton(onDelete,Modifier.align(Alignment.CenterEnd).size(64.dp).background(MaterialTheme.colorScheme.error,RoundedCornerShape(16.dp))) { Icon(Icons.Rounded.Delete,"删除成绩",tint = Color.White) }
        val largeText = density.fontScale >= 1.5f
        FlowRow(Modifier.fillMaxWidth().testTag("exam.row.${row.exam.id}").offset { IntOffset(animated.roundToInt(),0) }.background(MaterialTheme.colorScheme.surface)
            .draggable(rememberDraggableState { offset = (offset+it).coerceIn(-maxOffset,0f) },Orientation.Horizontal,onDragStopped = { offset = if(offset < -maxOffset*0.45f) -maxOffset else 0f })
            .clickable { if(offset < 0) offset = 0f else onEdit() }.padding(vertical = 12.dp)
            .semantics(mergeDescendants = true) { customActions = listOf(CustomAccessibilityAction("删除成绩") { onDelete(); true }) },horizontalArrangement = Arrangement.spacedBy(14.dp),verticalArrangement = Arrangement.spacedBy(12.dp),maxItemsInEachRow = if(largeText) 1 else 3) {
            if(!largeText) Icon(Icons.Rounded.Description,null,Modifier.size(42.dp).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),RoundedCornerShape(13.dp)).padding(10.dp),tint = MaterialTheme.colorScheme.primary)
            Column(Modifier.weight(1f),verticalArrangement = Arrangement.spacedBy(5.dp)) { Text(row.exam.examName.ifBlank { row.exam.examType },style = MaterialTheme.typography.titleSmall); Text(row.subject.name,style = MaterialTheme.typography.bodyMedium,color = MaterialTheme.colorScheme.onSurfaceVariant); Text(row.exam.calendarDate(),style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant) }
            Column(horizontalAlignment = Alignment.End,verticalArrangement = Arrangement.spacedBy(6.dp)) { Text(formatScore(row.exam.score),style = MaterialTheme.typography.headlineSmall); Text("/ ${formatScore(row.subject.fullScore)} · ${GradeCalculator.calculateGradeCustom(row.exam.score,row.subject.fullScore)}",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}
@Composable fun SubjectsScreen(state: PlatformState,vm: PlatformViewModel,onAdd: () -> Unit,onEdit: (Subject) -> Unit) {
    var deleting by remember { mutableStateOf<Subject?>(null) }
    StudyPage {
        StudyHeading("给努力，一个归属。",state.semester?.name)
        if(state.subjects.isEmpty()) StudyEmpty("先从一个科目开始","设置科目和满分后，就可以记录考试了。","添加科目",onAdd)
        for(group in state.analysis(false)) StudyPanel {
            StudyHeading(group.subject.name,"满分 ${formatScore(group.subject.fullScore)} · ${group.records.size} 次记录")
            StudySummary(group)
            Row(Modifier.fillMaxWidth(),horizontalArrangement = Arrangement.End) { TextButton(onClick = { onEdit(group.subject) }) { Text("编辑科目") }; TextButton(onClick = { deleting = group.subject }) { Text("删除",color = MaterialTheme.colorScheme.error) } }
        }
        if(state.subjects.isNotEmpty()) StudyPrimary("添加科目",onAdd,tag = "subjects.add.bottom")
    }
    deleting?.let { subject -> AlertDialog(onDismissRequest = { deleting = null },title = { Text("删除“${subject.name}”？") },text = { Text("将同时删除本科目 ${state.records.count { it.subject.id == subject.id }} 条成绩。此操作无法撤销。") },confirmButton = { TextButton(onClick = { val scope = state.scope; vm.run(onSuccess = { deleting = null }) { vm.repository.deleteSubject(subject,scope) } }) { Text("删除科目及成绩",color = MaterialTheme.colorScheme.error) } },dismissButton = { TextButton(onClick = { deleting = null }) { Text("取消") } }) }
}
@Composable fun RecordsScreen(records: List<ExamWithSubject>,vm: PlatformViewModel,onEdit: (ExamRecord) -> Unit) {
    var search by rememberSaveable { mutableStateOf("") }; var visible by rememberSaveable { mutableIntStateOf(50) }
    val filtered = remember(records,search) { records.filter { it.exam.examName.contains(search,true) || it.subject.name.contains(search,true) } }
    StudyPage {
        StudyField("搜索考试名称或科目",search,{ search = it; visible = 50 },tag = "records.search")
        StudyHeading("成绩明细","${filtered.size} 条 · 轻点编辑 · 左滑删除")
        if(filtered.isEmpty()) StudyEmpty("没有找到成绩","试试其他关键词，或先添加成绩。")
        else StudyPanel { for(row in filtered.take(visible)) ExamRow(row,{ onEdit(row.exam) },{ vm.delete(row.exam) }); if(filtered.size > visible) TextButton(onClick = { visible += 50 }) { Text("继续查看 50 条") } }
    }
}
