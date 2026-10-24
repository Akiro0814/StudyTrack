package com.repea.studytrack.viewmodel

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.*
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.utils.*
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.withLock
import java.time.ZoneId
import javax.inject.Inject

data class ImportPreview(val excel: ExcelPreview, val scope: PlatformScope, val revision: String)
data class AnalysisNavigation(val subject: Int?, val wholeStage: Boolean, val scope: PlatformScope? = null, val request: Long = System.nanoTime())

@HiltViewModel
class PlatformViewModel @Inject constructor(
    val repository: PlatformRepository, val backups: BackupRestoreService,
    private val exporter: BackupExporterV1, private val excel: ExcelHelper,
    @param:ApplicationContext private val context: Context
) : ViewModel() {
    val state = repository.state.stateIn(viewModelScope, SharingStarted.Eagerly, PlatformState())
    var initialized by mutableStateOf(false); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null)
    var notice by mutableStateOf<String?>(null)
    var deleted by mutableStateOf<Pair<ExamRecord,PlatformScope>?>(null); private set
    var importPreview by mutableStateOf<ImportPreview?>(null)
    var importReport by mutableStateOf<String?>(null)
    var backupPreview by mutableStateOf<BackupPreview?>(null)
    var analysisNavigation by mutableStateOf<AnalysisNavigation?>(null)
    private var undoJob: Job? = null
    private val drafts = mutableMapOf<String,Job>()
    init { initialize() }
    fun initialize() { viewModelScope.launch {
        try { withContext(Dispatchers.IO) { backups.completePendingRestore(); repository.initialize() }; initialized = true }
        catch (e: Exception) { error = e.message ?: "无法打开学习档案" }
    } }
    fun run(onSuccess: () -> Unit = {}, action: suspend () -> Unit) {
        if (busy) return
        busy = true; error = null
        viewModelScope.launch {
            try { withContext(Dispatchers.IO) { action() }; onSuccess(); refreshWidgets() }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (e: Exception) { error = e.message ?: "操作未完成，请重试" }
            finally { busy = false }
        }
    }
    fun refreshWidgets() {
        context.sendBroadcast(Intent("com.repea.studytrack.REFRESH_WIDGETS").setPackage(context.packageName))
    }
    fun delete(record: ExamRecord) {
        val scope = state.value.scope
        run(onSuccess = {
            deleted = record to scope; undoJob?.cancel()
            undoJob = viewModelScope.launch { delay(8000); deleted = null }
        }) { repository.deleteRecord(record, scope) }
    }
    fun undo() { val (record, scope) = deleted ?: return
        run(onSuccess = { deleted = null; undoJob?.cancel() }) { repository.restoreRecord(record, scope) }
    }
    fun dismissUndo() { deleted = null; undoJob?.cancel() }
    suspend fun draft(key: String) = withContext(Dispatchers.IO) { repository.database.platformMetadataDao().get("draft:$key") }
    fun saveDraft(key: String, json: String) {
        drafts.remove(key)?.cancel()
        drafts[key] = viewModelScope.launch { delay(200); withContext(Dispatchers.IO) { repository.database.platformMetadataDao().put(PlatformMetadata("draft:$key",json)) } }
    }
    suspend fun clearDraft(key: String) { drafts.remove(key)?.cancel(); repository.database.platformMetadataDao().remove("draft:$key") }
    fun inspectExcel(uri: Uri) = run {
        val snapshot = repository.snapshot()
        val preview = excel.readPreview(uri)
        val report = org.json.JSONObject().put("format","studytrack-import-report").put("formatVersion",1).put("sourceSHA256",preview.sourceDigest)
            .put("validRows",preview.records.size).put("issues",org.json.JSONArray(preview.issues)).put("conversions",org.json.JSONArray(preview.warnings))
        withContext(Dispatchers.Main) { importPreview = ImportPreview(preview, snapshot.scope, snapshot.revisionToken()); importReport = report.toString(2) }
    }
    fun importExcel(validOnly: Boolean = false,acceptConversions: Boolean = false) {
        val preview = importPreview ?: return
        run(onSuccess = { importPreview = null }) {
            require(repository.snapshot().revisionToken() == preview.revision) { "预览后数据已改变，请重新导入" }
            require(preview.excel.issues.isEmpty() || validOnly) { "请先修正错误，或明确选择仅导入有效行" }
            require(preview.excel.warnings.isEmpty() || acceptConversions) { "请明确接受已列出的日期与分类转换" }
            val counts = repository.importRecords(preview.excel.records, preview.scope)
            withContext(Dispatchers.Main) { notice = "已导入 ${counts.first} 条，跳过 ${counts.second} 条重复成绩"; importReport = org.json.JSONObject(importReport.orEmpty()).put("imported",counts.first).put("duplicates",counts.second).put("acceptedConversions",acceptConversions).put("validRowsOnly",validOnly).toString(2) }
        }
    }
    fun exportImportReport(uri: Uri) = run {
        val report = importReport ?: error("还没有导入报告")
        val output = context.contentResolver.openOutputStream(uri,"wt") ?: error("无法写入报告")
        output.use { it.write(report.toByteArray(Charsets.UTF_8)) }
    }
    fun exportExcel(uri: Uri) = run {
        val s = repository.snapshot()
        require(excel.exportToUri(uri, s.subjects, s.records, s.semester?.name ?: "当前学期")) { "无法写入 Excel 文件" }
        withContext(Dispatchers.Main) { notice = "Excel 已导出" }
    }
    fun exportBackup(uri: Uri, sourceTimeZone: String = ZoneId.systemDefault().id) = run {
        val zone = runCatching { ZoneId.of(sourceTimeZone.trim()) }.getOrElse { error("请输入有效时区，例如 Asia/Shanghai") }
        repository.mutationMutex.withLock { exporter.export(uri, zone.id) }
        withContext(Dispatchers.Main) { notice = "完整备份已保存。文件未加密，请妥善保管。" }
    }
    fun inspectBackup(uri: Uri) = run { val preview = backups.inspect(uri); withContext(Dispatchers.Main) { backupPreview = preview } }
    fun restoreBackup() { val preview = backupPreview ?: return
        run(onSuccess = { backupPreview = null; deleted = null; notice = "完整备份已恢复，恢复前快照已保存在本机。" }) { backups.restore(preview) }
    }
    fun inspectRecovery() = run { val preview = backups.inspect(backups.latestRecovery()); withContext(Dispatchers.Main) { backupPreview = preview } }
    fun openWidget(uri: Uri) {
        if (uri.scheme != "studytrack" || uri.host != "analysis") return
        run {
            val s = repository.snapshot()
            val user = uri.getQueryParameter("user")?.toIntOrNull() ?: s.scope.user
            val term = uri.getQueryParameter("semester")?.toIntOrNull() ?: s.scope.semester
            val subject = uri.getQueryParameter("subject")?.toIntOrNull()
            val whole = uri.getQueryParameter("stage") == "1"
            val target = s.copy(preferences = s.preferences.copy(currentUserId = user,currentSemesterId = term))
            require(subject == null || target.analysis(whole).any { it.subject.id == subject || it.records.any { row -> row.subject.id == subject } }) { "小组件对应科目已删除，请重新配置" }
            repository.select(PlatformScope(user,term))
            withContext(Dispatchers.Main) { analysisNavigation = AnalysisNavigation(subject,whole,PlatformScope(user,term)) }
        }
    }
}
