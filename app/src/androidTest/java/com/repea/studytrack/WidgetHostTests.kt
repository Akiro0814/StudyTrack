package com.repea.studytrack

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.repea.studytrack.data.local.entity.ExamRecord
import com.repea.studytrack.domain.*
import com.repea.studytrack.widget.StudyWidgetProvider
import kotlinx.coroutines.runBlocking
import org.junit.*
import org.junit.Assert.*

class WidgetHostTests {
    @Before fun reset() { clearFixture() }
    @Test fun realWidgetHostReceivesScoresAndReflectsDeletion() = runBlocking {
        val repo = testAccess().repository(); repo.createProfile("组件测试",SchoolTerm(SchoolStage.HIGH,1,1),true)
        var state = repo.snapshot(); repo.saveSubject("数学","100",state.scope); state = repo.snapshot()
        repo.saveRecords(listOf(ExamRecord(subjectId=state.subjects.single().id,examName="组件考试",examDate=RecordValidation.date("2026-10-24"),score=85.25,examType="月考",userId=state.scope.user,semesterId=state.scope.semester)),state.scope)
        val context = ApplicationProvider.getApplicationContext<Context>(); val instrumentation = InstrumentationRegistry.getInstrumentation()
        val manager = AppWidgetManager.getInstance(context); val provider = ComponentName(context,StudyWidgetProvider::class.java)
        lateinit var host: AppWidgetHost; lateinit var view: AppWidgetHostView; var id = -1
        instrumentation.uiAutomation.adoptShellPermissionIdentity("android.permission.BIND_APPWIDGET")
        try {
            instrumentation.runOnMainSync { host = AppWidgetHost(context,20261024); id = host.allocateAppWidgetId(); assertTrue(manager.bindAppWidgetIdIfAllowed(id,provider)); host.startListening(); view = host.createView(context,id,manager.getAppWidgetInfo(id)) }
            fun refresh() { context.sendBroadcast(Intent(context,StudyWidgetProvider::class.java).setAction("com.repea.studytrack.REFRESH_WIDGETS")) }
            fun waitScore(expected: String) {
                val end = System.currentTimeMillis()+10000
                while(System.currentTimeMillis() < end) {
                    var actual: String? = null
                    instrumentation.runOnMainSync { actual = view.findViewById<TextView>(R.id.widget_score)?.text?.toString() }
                    if(actual == expected) return
                    Thread.sleep(100)
                }
                fail("Widget did not display $expected")
            }
            refresh(); waitScore("85.25")
            val current = repo.snapshot(); repo.deleteRecord(current.records.single().exam,current.scope)
            refresh(); waitScore("—")
        } finally {
            instrumentation.runOnMainSync { if(id != -1) { host.stopListening(); host.deleteHost() } }
            instrumentation.uiAutomation.dropShellPermissionIdentity()
        }
    }
}
