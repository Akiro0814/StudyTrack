package com.repea.studytrack.ui.parity

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.dp
import com.repea.studytrack.data.local.entity.ExamRecord
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.viewmodel.PlatformViewModel
import kotlin.math.abs

@Composable fun AnalysisScreen(state: PlatformState,vm: PlatformViewModel,onRecord: (String) -> Unit,onEdit: (ExamRecord) -> Unit) {
    var wholeStage by rememberSaveable { mutableStateOf(false) }; var selected by rememberSaveable { mutableStateOf("") }
    var search by rememberSaveable { mutableStateOf("") }; var metric by rememberSaveable { mutableIntStateOf(0) }
    val groups = remember(state,wholeStage) { state.analysis(wholeStage) }
    val visible = groups.filter { selected.isEmpty() || it.key == selected }
    LaunchedEffect(state.scope) { selected = ""; if(vm.analysisNavigation == null) { wholeStage = false; metric = 0 } }
    LaunchedEffect(vm.analysisNavigation,groups) { vm.analysisNavigation?.let { route ->
        if(route.scope != null && state.scope != route.scope) return@let
        wholeStage = route.wholeStage
        if(route.subject != null) selected = state.analysis(route.wholeStage).firstOrNull { it.subject.id == route.subject || it.records.any { row -> row.subject.id == route.subject } }?.key.orEmpty()
        vm.analysisNavigation = null
    } }
    StudyPage {
        StudyHeading("看见每一步变化。")
        StudySegments(listOf("本学期","学习阶段汇总"),if(wholeStage) 1 else 0) { wholeStage = it == 1; selected = "" }
        Text(if(wholeStage) "${state.semester?.schoolTerm?.stage?.label ?: "请先归类当前学期"} · 全部已建学期" else state.semester?.name.orEmpty(),style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        StudyPicker("科目",if(selected.isEmpty()) "全部科目" else groups.firstOrNull { it.key == selected }?.let { "${it.subject.name} · ${formatScore(it.subject.fullScore)}分制" }.orEmpty(),listOf("全部科目")+groups.map { "${it.subject.name} · ${formatScore(it.subject.fullScore)}分制" },{ selected = if(it == 0) "" else groups[it-1].key })
        StudyField("搜索考试名称",search,{ search = it },tag = "analysis.search")
        if(groups.all { it.records.isEmpty() }) StudyEmpty("你的曲线，等待起笔","记录考试后，在这里回看成长。","添加成绩") { onRecord("single") }
        else {
            if(selected.isEmpty()) visible.filter { it.records.isNotEmpty() }.groupBy { it.subject.fullScore }.toSortedMap().forEach { (full, sameFull) -> StudyPanel { StudyHeading("${formatScore(full)} 分制","${sameFull.size} 科"); TrendChart(sameFull,0) } }
            else if(visible.isNotEmpty()) StudyPanel {
                StudySegments(listOf("分数","班排","年排","区排"),metric) { metric = it }
                TrendChart(visible,metric)
            }
            for(group in visible) StudyPanel {
                StudyHeading(group.subject.name,"满分 ${formatScore(group.subject.fullScore)}")
                StudySummary(group)
                var expanded by rememberSaveable(group.key) { mutableStateOf(false) }; var count by rememberSaveable(group.key) { mutableIntStateOf(50) }
                TextButton(onClick = { expanded = !expanded }) { Text("${if(expanded) "收起" else "查看"} ${group.records.size} 条成绩明细") }
                if(expanded) {
                    val rows = group.records.asReversed().filter { it.exam.examName.contains(search,true) }
                    if(rows.isEmpty()) Text("没有匹配的成绩",color = MaterialTheme.colorScheme.onSurfaceVariant)
                    for(row in rows.take(count)) ExamRow(row,{ onEdit(row.exam) },{ vm.delete(row.exam) })
                    if(rows.size > count) TextButton(onClick = { count += 50 }) { Text("继续查看 50 条") }
                }
            }
            TextButton(onClick = { onRecord("batch") },Modifier.fillMaxWidth()) { Text("一次考试，多科录入") }
        }
    }
}

@Composable fun TrendChart(groups: List<SubjectHistory>, metric: Int) {
    val points = remember(groups,metric) { TrendSeries.points(groups,metric) }
    val plotted = remember(points) { points.groupBy { it.group }.values.flatMap { TrendSeries.sample(it) } }
    var highlighted by remember(points) { mutableStateOf<TrendPoint?>(points.maxByOrNull { it.x }) }
    val reveal = remember { Animatable(0f) }
    LaunchedEffect(points) { reveal.snapTo(0f); reveal.animateTo(1f,tween(650)) }
    if(points.isEmpty()) { Text("暂无此项排名，补充排名后即可查看趋势。",style = MaterialTheme.typography.bodyMedium,color = MaterialTheme.colorScheme.onSurfaceVariant); return }
    val accent = MaterialTheme.colorScheme.primary; val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    val colors = groups.indices.map { if(groups.size == 1) accent else Color.hsv(((0.61 + it*0.61803398875)%1*360).toFloat(),0.7f,0.8f) }
    val lowX = points.minOf { it.x }; val highX = points.maxOf { it.x }; val spanX = (highX-lowX).coerceAtLeast(1.0)
    val maxY = if(metric == 0) groups.first().subject.fullScore else (points.maxOf { it.value }*1.1).coerceAtLeast(2.0)
    highlighted?.let { point ->
        Text(if(metric == 0) "${formatScore(point.value)} 分" else "${point.value.toInt()} 名",style = MaterialTheme.typography.headlineLarge,color = colors[point.group])
        Text("${point.row.subject.name} · ${point.row.exam.calendarDate()} · ${point.row.exam.examName.ifBlank { point.row.exam.examType }}",style = MaterialTheme.typography.bodySmall,color = secondary)
    }
    Canvas(Modifier.fillMaxWidth().height(230.dp).testTag("analysis.chart").semantics { contentDescription = "${points.size} 条${if(metric == 0) "成绩" else "排名"}趋势，轻点查看考试" }
        .pointerInput(points) { detectTapGestures { position ->
            val x = lowX + ((position.x-16.dp.toPx())/(size.width-32.dp.toPx())).coerceIn(0f,1f)*spanX
            highlighted = points.minByOrNull { abs(it.x-x) }
        } }) {
        val pad = 16.dp.toPx(); val width = size.width-pad*2; val height = size.height-pad*2
        fun position(point: TrendPoint): Offset {
            val x = if(highX == lowX) pad+width/2 else pad+((point.x-lowX)/spanX*width).toFloat()
            val y = pad + (if(metric == 0) (1-point.value/maxY) else point.value/maxY).toFloat()*height
            return Offset(x,y.coerceIn(pad,pad+height))
        }
        repeat(5) { i -> val y = pad+height*i/4; drawLine(secondary.copy(alpha = 0.12f),Offset(pad,y),Offset(pad+width,y),1.dp.toPx()) }
        clipRect(right = size.width*reveal.value) {
            for((group, rows) in plotted.groupBy { it.group }) {
                val path = Path(); val positions = rows.map(::position)
                positions.forEachIndexed { index,p -> if(index == 0) path.moveTo(p.x,p.y) else { val old = positions[index-1]; val mid = (old.x+p.x)/2; path.cubicTo(mid,old.y,mid,p.y,p.x,p.y) } }
                if(groups.size == 1 && metric == 0 && positions.size > 1) { val area = Path().apply { addPath(path); lineTo(positions.last().x,pad+height); lineTo(positions.first().x,pad+height); close() }; drawPath(area,Brush.verticalGradient(listOf(colors[group].copy(alpha = 0.16f),Color.Transparent))) }
                drawPath(path,colors[group],style = Stroke(2.5.dp.toPx(),cap = StrokeCap.Round))
                positions.forEach { drawCircle(colors[group],2.5.dp.toPx(),it) }
            }
        }
        highlighted?.let { val p = position(it); drawLine(secondary.copy(alpha = 0.35f),Offset(p.x,pad),Offset(p.x,pad+height),1.dp.toPx()); drawCircle(colors[it.group],5.dp.toPx(),p) }
    }
    Row(Modifier.fillMaxWidth(),horizontalArrangement = Arrangement.SpaceBetween) { Text(if(groups.size == 1) "第 1 次" else points.minBy { it.x }.row.exam.calendarDate(),style = MaterialTheme.typography.labelSmall,color = secondary); Text(if(groups.size == 1) "第 ${groups.first().records.size} 次" else points.maxBy { it.x }.row.exam.calendarDate(),style = MaterialTheme.typography.labelSmall,color = secondary) }
    for((index,group) in groups.withIndex()) Text("● ${group.subject.name}",style = MaterialTheme.typography.bodySmall,color = colors[index])
    Text(if(metric == 0) "轻点曲线查看考试 · 同日考试独立显示" else "排名越小越靠上 · 未填写的排名保留空缺",style = MaterialTheme.typography.bodySmall,color = secondary)
}
