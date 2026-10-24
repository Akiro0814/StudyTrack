package com.repea.studytrack.ui.parity

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.viewmodel.PlatformViewModel
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.YearMonth

private val examTypes = listOf("月考","期中","期末","其他")
private fun draft(subject: Int,existing: ExamRecord? = null) = JSONObject().put("subject",existing?.subjectId ?: subject).put("name",existing?.examName ?: "")
    .put("date",existing?.calendarDate() ?: LocalDate.now().toString()).put("score",existing?.let { formatScore(it.score) } ?: "")
    .put("type",existing?.examType ?: "月考").put("class",existing?.classRank?.toString() ?: "").put("grade",existing?.gradeRank?.toString() ?: "")
    .put("district",existing?.districtRank?.toString() ?: "").put("reflection",existing?.reflection ?: "")
private fun input(form: JSONObject,scope: PlatformScope,subjects: List<Subject>,existing: ExamRecord? = null): ExamRecord {
    val subject = subjects.firstOrNull { it.id == form.optInt("subject") } ?: error("请选择一个可用科目")
    val name = form.optString("name").trim(); require(name.length <= 100) { "考试名称超过 100 字" }
    val reflection = form.optString("reflection"); require(reflection.length <= 10000) { "反思超过 10000 字" }
    return ExamRecord(id = existing?.id ?: 0,subjectId = subject.id,examName = name,examDate = RecordValidation.date(form.getString("date")),score = RecordValidation.score(form.getString("score"),subject.fullScore),examType = form.getString("type"),
        classRank = RecordValidation.rank(form.optString("class")),gradeRank = RecordValidation.rank(form.optString("grade")),districtRank = RecordValidation.rank(form.optString("district")),reflection = reflection.takeIf { it.isNotBlank() },imageUri = existing?.imageUri,userId = scope.user,semesterId = subject.semesterId,dateOnly = form.getString("date"))
}
@Composable private fun EditorHeader(title: String,busy: Boolean,onClose: () -> Unit,onSave: () -> Unit,save: String = "保存") {
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp),verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClose,enabled = !busy) { Text("取消") }; Spacer(Modifier.weight(1f)); Text(title,style = MaterialTheme.typography.titleSmall); Spacer(Modifier.weight(1f)); TextButton(onSave,enabled = !busy) { Text(save) }
    }
}
@Composable fun SubjectEditor(state: PlatformState,vm: PlatformViewModel,existing: Subject?,onClose: () -> Unit,onSaved: () -> Unit) {
    val scope = remember { state.scope }; var name by rememberSaveable { mutableStateOf(existing?.name.orEmpty()) }; var full by rememberSaveable { mutableStateOf(existing?.fullScore?.let(::formatScore) ?: "100") }
    val keyboard = LocalSoftwareKeyboardController.current
    Column {
        EditorHeader(if(existing == null) "添加科目" else "编辑科目",vm.busy,onClose,{ val title = name; val maximum = full; keyboard?.hide(); vm.run(onSuccess = onSaved) { vm.repository.saveSubject(title,maximum,scope,existing) } })
        StudyPage {
            StudyPanel { StudyField("科目名称",name,{ name = it },tag = "subject.name",enabled = !vm.busy); StudyField("满分",full,{ full = it },keyboard = KeyboardType.Decimal,tag = "subject.full",enabled = !vm.busy) }
            Text("每个学期独立设置满分。修改满分不会改变历史分数，也不能低于已有成绩。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
@Composable fun ExamEditor(state: PlatformState,vm: PlatformViewModel,existing: ExamRecord?,onClose: () -> Unit) {
    val scope = remember { state.scope }; val termID = existing?.semesterId ?: scope.semester
    val subjects = state.allSubjects.filter { it.userId == scope.user && it.semesterId == termID }
    val initial = remember { draft(subjects.firstOrNull()?.id ?: 0,existing).toString() }
    var raw by rememberSaveable { mutableStateOf(initial) }; var loaded by remember { mutableStateOf(false) }; var recovered by remember { mutableStateOf<String?>(null) }; var closing by remember { mutableStateOf(false) }
    val key = "exam:${scope.user}:$termID:${existing?.id ?: 0}"
    val form = remember(raw) { JSONObject(raw) }
    fun update(field: String,value: Any) { raw = JSONObject(raw).put(field,value).toString() }
    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(key) { recovered = vm.draft(key); loaded = true }
    LaunchedEffect(raw,loaded,recovered) { if(loaded && recovered == null) vm.saveDraft(key,raw) }
    LaunchedEffect(subjects) { if(form.optInt("subject") == 0 && subjects.isNotEmpty()) update("subject",subjects.first().id) }
    Column {
        EditorHeader(if(existing == null) "添加成绩" else "编辑成绩",vm.busy,{ if(raw != initial) closing = true else onClose() },{
            val submitted = raw; keyboard?.hide()
            vm.run(onSuccess = onClose) { vm.repository.saveRecords(listOf(input(JSONObject(submitted),scope,subjects,existing)),scope); vm.clearDraft(key) }
        })
        StudyPage {
            StudyPanel {
                StudyHeading("考试")
                StudyPicker("科目",subjects.firstOrNull { it.id == form.optInt("subject") }?.name ?: "请选择",subjects.map { it.name },{ update("subject",subjects[it].id) },"exam.subject")
                StudyPicker("类型",form.getString("type"),examTypes,{ update("type",examTypes[it]) })
                StudyField("考试名称",form.getString("name"),{ update("name",it) },placeholder = "留空使用类型名称",enabled = !vm.busy)
                StudyDateField(form.getString("date")) { update("date",it) }
            }
            StudyPanel {
                StudyHeading("成绩",subjects.firstOrNull { it.id == form.optInt("subject") }?.let { "满分 ${formatScore(it.fullScore)}" })
                StudyField("分数",form.getString("score"),{ update("score",it) },keyboard = KeyboardType.Decimal,tag = "exam.score",enabled = !vm.busy)
            }
            StudyPanel { RankFields(form,{ field,value -> update(field,value) },vm.busy) }
            StudyPanel { StudyField("反思",form.getString("reflection"),{ update("reflection",it) },multiline = true,placeholder = "有哪些值得记住的经验？",enabled = !vm.busy) }
            Text("填写中会保留草稿，下次打开可继续编辑。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    if(recovered != null) AlertDialog(onDismissRequest = { },title = { Text("发现未保存草稿") },text = { Text("此草稿仅属于当前用户和学期。") },confirmButton = { TextButton(onClick = { recovered?.let { if(runCatching { JSONObject(it) }.isSuccess) raw = it }; recovered = null }) { Text("继续编辑草稿") } },dismissButton = { TextButton(onClick = { vm.run { vm.clearDraft(key) }; recovered = null }) { Text("丢弃草稿") } })
    if(closing) DraftCloseDialog({ closing = false },{ vm.saveDraft(key,raw); onClose() },{ vm.run(onSuccess = onClose) { vm.clearDraft(key) } })
}
@Composable private fun RankFields(form: JSONObject,update: (String,String) -> Unit,busy: Boolean) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    TextButton(onClick = { expanded = !expanded }) { Text("${if(expanded) "收起" else "补充"}排名（可选）") }
    if(expanded) for((key,title) in listOf("class" to "班排","grade" to "年排","district" to "区排")) StudyField(title,form.optString(key),{ update(key,it) },keyboard = KeyboardType.Number,enabled = !busy)
}
@Composable private fun DraftCloseDialog(onContinue: () -> Unit,onKeep: () -> Unit,onDiscard: () -> Unit) {
    AlertDialog(onDismissRequest = onContinue,title = { Text("保留未保存的修改？") },text = { Text("保留草稿后，下次打开可以继续编辑。") },confirmButton = { TextButton(onKeep) { Text("保留草稿并关闭") } },dismissButton = { Row { TextButton(onDiscard) { Text("放弃修改",color = MaterialTheme.colorScheme.error) }; TextButton(onContinue) { Text("继续编辑") } } })
}
@Composable fun BatchEditor(state: PlatformState,vm: PlatformViewModel,onClose: () -> Unit) {
    val scope = remember { state.scope }; val subjects = state.subjects
    val initial = remember { JSONObject().put("name","").put("date",LocalDate.now().toString()).put("type","月考").put("rows",JSONArray().put(draft(subjects.firstOrNull()?.id ?: 0))).toString() }
    var raw by rememberSaveable { mutableStateOf(initial) }; var loaded by remember { mutableStateOf(false) }; var recovered by remember { mutableStateOf<String?>(null) }; var closing by remember { mutableStateOf(false) }
    val form = remember(raw) { JSONObject(raw) }; val rows = form.getJSONArray("rows"); val key = "batch:${scope.user}:${scope.semester}"
    fun update(field: String,value: Any) { raw = JSONObject(raw).put(field,value).toString() }
    fun rowUpdate(index: Int,field: String,value: Any) { val next = JSONObject(raw); next.getJSONArray("rows").getJSONObject(index).put(field,value); raw = next.toString() }
    LaunchedEffect(key) { recovered = vm.draft(key); loaded = true }
    LaunchedEffect(raw,loaded,recovered) { if(loaded && recovered == null) vm.saveDraft(key,raw) }
    Column {
        EditorHeader("批量录入",vm.busy,{ if(raw != initial) closing = true else onClose() },{
            val submitted = raw
            vm.run(onSuccess = onClose) {
                val data = JSONObject(submitted); val all = data.getJSONArray("rows")
                require(all.length() > 0) { "至少填写一行" }
                val inputs = (0 until all.length()).map { i ->
                    val row = all.getJSONObject(i); row.put("name",data.getString("name")).put("date",data.getString("date")).put("type",data.getString("type"))
                    try { input(row,scope,subjects) } catch(e: Exception) { throw IllegalArgumentException("第 ${i+1} 行：${e.message}") }
                }
                require(inputs.map { it.subjectId }.toSet().size == inputs.size) { "同批次科目不能重复" }
                vm.repository.saveRecords(inputs,scope); vm.clearDraft(key)
            }
        },"保存全部")
        StudyPage {
            StudyPanel { StudyHeading("同一次考试"); StudyField("考试名称",form.getString("name"),{ update("name",it) },enabled = !vm.busy); StudyPicker("类型",form.getString("type"),examTypes,{ update("type",examTypes[it]) }); StudyDateField(form.getString("date")) { update("date",it) } }
            for(index in 0 until rows.length()) {
                val row = rows.getJSONObject(index)
                StudyPanel {
                    StudyHeading("第 ${index+1} 科")
                    StudyPicker("科目",subjects.firstOrNull { it.id == row.optInt("subject") }?.name ?: "请选择",subjects.map { it.name },{ rowUpdate(index,"subject",subjects[it].id) })
                    StudyField("分数",row.optString("score"),{ rowUpdate(index,"score",it) },keyboard = KeyboardType.Decimal,tag = "batch.score.$index",enabled = !vm.busy)
                    RankFields(row,{ field,value -> rowUpdate(index,field,value) },vm.busy)
                    StudyField("反思（可选）",row.optString("reflection"),{ rowUpdate(index,"reflection",it) },multiline = true,enabled = !vm.busy)
                    TextButton(onClick = { val next = JSONObject(raw); next.getJSONArray("rows").remove(index); raw = next.toString() }) { Text("移除此行",color = MaterialTheme.colorScheme.error) }
                }
            }
            StudyPrimary("添加一行",{ val next = JSONObject(raw); val used = (0 until rows.length()).map { rows.getJSONObject(it).optInt("subject") }.toSet(); next.getJSONArray("rows").put(draft(subjects.firstOrNull { it.id !in used }?.id ?: 0)); raw = next.toString() },enabled = rows.length() < subjects.size)
            Text("每个科目只能出现一次；所有行校验通过后一起保存，失败不会留下部分成绩。",style = MaterialTheme.typography.bodySmall,color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    if(recovered != null) AlertDialog(onDismissRequest = { },title = { Text("继续上次的批量录入？") },confirmButton = { TextButton(onClick = { recovered?.let { if(runCatching { JSONObject(it).getJSONArray("rows") }.isSuccess) raw = it }; recovered = null }) { Text("恢复草稿") } },dismissButton = { TextButton(onClick = { vm.run { vm.clearDraft(key) }; recovered = null }) { Text("丢弃草稿") } })
    if(closing) DraftCloseDialog({ closing = false },{ vm.saveDraft(key,raw); onClose() },{ vm.run(onSuccess = onClose) { vm.clearDraft(key) } })
}

@Composable fun StudyDateField(value: String,onChange: (String) -> Unit) {
    var open by rememberSaveable { mutableStateOf(false) }
    StudyField("日期 yyyy-MM-dd",value,onChange,tag = "exam.date")
    TextButton(onClick = { open = !open }) { Text(if(open) "收起日历" else "从日历选择") }
    if(open) {
        var monthText by rememberSaveable { mutableStateOf(runCatching { YearMonth.from(LocalDate.parse(value)) }.getOrDefault(YearMonth.now()).toString()) }
        val month = YearMonth.parse(monthText)
        Row(Modifier.fillMaxWidth(),horizontalArrangement = Arrangement.SpaceBetween,verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { monthText = month.minusMonths(1).toString() },enabled = month.year > 1900 || month.monthValue > 1) { Text("‹") }
            Text("${month.year} 年 ${month.monthValue} 月",style = MaterialTheme.typography.titleSmall)
            TextButton(onClick = { monthText = month.plusMonths(1).toString() },enabled = month.year < 2100 || month.monthValue < 12) { Text("›") }
        }
        Row(Modifier.fillMaxWidth()) { "一二三四五六日".forEach { Text(it.toString(),Modifier.weight(1f),textAlign = androidx.compose.ui.text.style.TextAlign.Center,style = MaterialTheme.typography.bodySmall) } }
        val offset = month.atDay(1).dayOfWeek.value-1
        for(week in 0 until (offset+month.lengthOfMonth()+6)/7) Row(Modifier.fillMaxWidth()) {
            for(column in 0..6) {
                val day = week*7+column-offset+1
                Box(Modifier.weight(1f).heightIn(min = 44.dp),contentAlignment = Alignment.Center) { if(day in 1..month.lengthOfMonth()) {
                    val date = month.atDay(day).toString()
                    Box(Modifier.size(40.dp).background(if(date == value) MaterialTheme.colorScheme.primary else androidx.compose.ui.graphics.Color.Transparent,CircleShape).clickable { onChange(date); open = false },contentAlignment = Alignment.Center) { Text(day.toString(),color = if(date == value) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface) }
                } }
            }
        }
    }
}
