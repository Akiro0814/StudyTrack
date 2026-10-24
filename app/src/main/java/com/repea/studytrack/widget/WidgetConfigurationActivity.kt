package com.repea.studytrack.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.repea.studytrack.repository.PlatformRepository
import com.repea.studytrack.repository.PlatformState
import com.repea.studytrack.ui.parity.*
import com.repea.studytrack.ui.theme.StudyTrackTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class WidgetConfigurationActivity : ComponentActivity() {
    @Inject lateinit var repository: PlatformRepository
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState); setResult(RESULT_CANCELED)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,AppWidgetManager.INVALID_APPWIDGET_ID)
        if(id == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }
        setContent {
            val state by repository.state.collectAsState(PlatformState())
            var selected by rememberSaveable { mutableStateOf<String?>(getSharedPreferences("widgets",MODE_PRIVATE).getString("selection:$id",null)) }
            val options = remember(state) { WidgetOptions.make(state) }
            StudyTrackTheme(state.preferences.themeStyle,state.preferences.displayMode,state.preferences.accentHex) {
                Surface {
                    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(20.dp),verticalArrangement = Arrangement.spacedBy(24.dp)) {
                        StudyHeading("学迹成绩趋势","选择档案、学期或学习阶段和科目")
                        StudyPicker("成绩范围",options.firstOrNull { it.id == selected }?.label ?: "自动：当前学期最近成绩",listOf("自动：当前学期最近成绩")+options.map { it.label },{ selected = if(it == 0) null else options[it-1].id })
                        Text("关闭多用户模式时，只能选择当前用户。没有成绩时会显示引导，记录后自动更新。",style = MaterialTheme.typography.bodySmall)
                        StudyPrimary("添加小组件",{
                            getSharedPreferences("widgets",MODE_PRIVATE).edit().apply { if(selected == null) remove("selection:$id") else putString("selection:$id",selected) }.apply()
                            sendBroadcast(Intent(this@WidgetConfigurationActivity,StudyWidgetProvider::class.java).setAction("com.repea.studytrack.REFRESH_WIDGETS"))
                            setResult(RESULT_OK,Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id)); finish()
                        },enabled = state.loaded)
                        TextButton(onClick = { finish() }) { Text("取消") }
                    }
                }
            }
        }
    }
}
