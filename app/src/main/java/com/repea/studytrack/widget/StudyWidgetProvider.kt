package com.repea.studytrack.widget

import android.app.PendingIntent
import android.appwidget.*
import android.content.*
import android.graphics.*
import android.view.View
import android.widget.RemoteViews
import com.repea.studytrack.MainActivity
import com.repea.studytrack.R
import com.repea.studytrack.domain.formatScore
import com.repea.studytrack.repository.PlatformRepository
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import javax.inject.Inject

@AndroidEntryPoint
class StudyWidgetProvider : AppWidgetProvider() {
    @Inject lateinit var repository: PlatformRepository
    override fun onReceive(context: Context,intent: Intent) {
        super.onReceive(context,intent)
        if(intent.action == "com.repea.studytrack.REFRESH_WIDGETS") enqueue(context,AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context,StudyWidgetProvider::class.java)))
    }
    override fun onUpdate(context: Context,manager: AppWidgetManager,ids: IntArray) { enqueue(context,ids) }
    private fun enqueue(context: Context,ids: IntArray) {
        if(ids.isEmpty()) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val state = repository.snapshot(); val restoring = repository.database.platformMetadataDao().get("pendingPreferences") != null
                val options = if(restoring) emptyList() else WidgetOptions.make(state)
                val settings = context.getSharedPreferences("widgets",Context.MODE_PRIVATE)
                for(id in ids) {
                    val choice = settings.getString("selection:$id",null)
                    val option = if(choice == null) WidgetOptions.default(state,options) else options.firstOrNull { it.id == choice }
                    val dark = state.preferences.displayMode == "dark" || (state.preferences.displayMode == "system" && (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES)
                    val view = RemoteViews(context.packageName,R.layout.widget_grades)
                    view.setInt(R.id.widget_root,"setBackgroundResource",if(dark) R.drawable.widget_background_dark else R.drawable.widget_background)
                    val primary = if(dark) Color.WHITE else Color.rgb(28,28,30); val secondary = if(dark) Color.rgb(174,174,178) else Color.rgb(99,99,102)
                    for(text in listOf(R.id.widget_title,R.id.widget_score)) view.setTextColor(text,primary)
                    for(text in listOf(R.id.widget_subtitle,R.id.widget_summary)) view.setTextColor(text,secondary)
                    view.setTextViewText(R.id.widget_title,option?.history?.subject?.name ?: "学迹")
                    view.setTextViewText(R.id.widget_score,option?.history?.records?.lastOrNull()?.exam?.score?.let(::formatScore) ?: "—")
                    view.setTextViewText(R.id.widget_subtitle,option?.let { "${it.userName} · ${it.semesterName}" } ?: if(choice != null) "原成绩范围不可用，请重新配置" else "打开学迹，选择科目并记录成绩")
                    val history = option?.history
                    view.setTextViewText(R.id.widget_summary,if(history != null && history.records.isNotEmpty()) "均分 ${String.format(java.util.Locale.ROOT,"%.1f",history.average)}   最高 ${history.maximum?.let(::formatScore)}   优秀率 ${history.excellence}%" else "成绩默认保存在本机")
                    if(history != null && history.records.isNotEmpty()) {
                        val values = history.records.takeLast(120).map { it.exam.score }
                        val bitmap = Bitmap.createBitmap(600,160,Bitmap.Config.ARGB_8888); val canvas = Canvas(bitmap)
                        val accent = runCatching { Color.parseColor(state.preferences.accentHex) }.getOrDefault(Color.BLUE)
                        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent; strokeWidth = 5f; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }
                        val path = Path()
                        values.forEachIndexed { index, score -> val x = if(values.size == 1) 300f else 12+576f*index/(values.size-1); val y = (148-136*score/history.subject.fullScore).toFloat(); if(index == 0) path.moveTo(x,y) else path.lineTo(x,y) }
                        if(values.size == 1) { paint.style = Paint.Style.FILL; canvas.drawCircle(300f,(148-136*values[0]/history.subject.fullScore).toFloat(),6f,paint) } else canvas.drawPath(path,paint)
                        view.setImageViewBitmap(R.id.widget_chart,bitmap); view.setViewVisibility(R.id.widget_chart,View.VISIBLE)
                    } else view.setViewVisibility(R.id.widget_chart,View.GONE)
                    val intent = Intent(context,MainActivity::class.java).setData(option?.deepLink ?: android.net.Uri.parse("studytrack://analysis")).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    view.setOnClickPendingIntent(R.id.widget_root,PendingIntent.getActivity(context,id,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                    AppWidgetManager.getInstance(context).updateAppWidget(id,view)
                }
            } catch(error: Exception) {
                android.util.Log.w("StudyTrackWidget","Widget refresh failed",error)
                for(id in ids) { val view = RemoteViews(context.packageName,R.layout.widget_grades); view.setTextViewText(R.id.widget_subtitle,"暂时无法读取，打开学迹后重试"); AppWidgetManager.getInstance(context).updateAppWidget(id,view) }
            } finally { pending.finish() }
        }
    }
    override fun onDeleted(context: Context,ids: IntArray) { val edit = context.getSharedPreferences("widgets",Context.MODE_PRIVATE).edit(); ids.forEach { edit.remove("selection:$it") }; edit.apply() }
}
