package com.repea.studytrack

import android.content.Context
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.repea.studytrack.data.local.entity.ExamRecord
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.AppThemeStyle
import kotlinx.coroutines.runBlocking
import org.junit.*
import java.io.File

class PlatformUITests {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    @Before fun reset() { clearFixture(); waitTag("guide.skip") }
    private fun waitTag(tag: String) {
        try { compose.waitUntil(15000) { runCatching { compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }.getOrDefault(false) }; compose.waitForIdle() }
        catch(error: Throwable) { image("failure-${tag.replace('.','-')}"); val tree=runCatching { compose.onRoot(useUnmergedTree=true).printToString() }.getOrDefault("App has no active Compose hierarchy"); throw AssertionError("Waiting for $tag\n$tree",error) }
    }
    private fun image(name: String) {
        val context = ApplicationProvider.getApplicationContext<Context>()
        compose.waitForIdle()
        // Hardware composition and Coil decoding finish after Compose becomes idle.
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        android.os.SystemClock.sleep(700)
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot() ?: error("Could not capture emulator screen")
        val values = android.content.ContentValues().apply { put(android.provider.MediaStore.Images.Media.DISPLAY_NAME,"$name.png"); put(android.provider.MediaStore.Images.Media.MIME_TYPE,"image/png"); put(android.provider.MediaStore.Images.Media.RELATIVE_PATH,"Pictures/StudyTrackTests") }
        val uri = context.contentResolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values) ?: error("Could not save screenshot")
        context.contentResolver.openOutputStream(uri)!!.use { check(bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it)) }; bitmap.recycle()
    }
    private fun onboard() {
        compose.onNodeWithTag("guide.skip").performClick(); waitTag("onboarding.name")
        compose.onNodeWithTag("onboarding.name").performTextInput("UI测试学生")
        compose.onNodeWithTag("onboarding.start").performScrollTo().performClick(); waitTag("home.add")
    }
    @Test fun completeGuideCoversEveryFunctionAndEntersProfileSetup() {
        val titles = listOf("从你的学习档案开始","给每次努力一个归属","一科，或整场考试","让记录随时可找","看见每一步变化","让旧记录也加入旅程","让记录安心留存","把学迹变成你的样子")
        for(title in titles) { compose.onNodeWithText(title).performScrollTo().assertIsDisplayed(); compose.onNodeWithTag("guide.next").performClick(); compose.waitForIdle() }
        waitTag("onboarding.name"); image("01-profile-setup")
    }
    @Test fun firstRecordCreatesSubjectAndSavesThenEditsAndUndoesDelete() {
        onboard(); compose.onNodeWithTag("home.add").performClick()
        compose.onNodeWithText("先添加一个科目").assertIsDisplayed(); compose.onNodeWithText("添加科目").performClick()
        waitTag("subject.name"); compose.onNodeWithTag("subject.name").performTextInput("数学")
        compose.onNodeWithText("保存").performClick(); waitTag("exam.score")
        compose.onNodeWithTag("exam.score").performTextInput("85.25"); compose.onNodeWithText("保存").performClick(); waitTag("home.add")
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().records.size == 1 } }
        image("02-home-first-record")
        compose.onNodeWithTag("tab.2").performClick(); waitTag("analysis.chart"); image("03-analysis-score")
        compose.onNodeWithText("查看 1 条成绩明细").performScrollTo().performClick()
        val id = runBlocking { testAccess().repository().snapshot().records.single().exam.id }
        compose.onNodeWithTag("exam.row.$id").performScrollTo().performClick(); waitTag("exam.score")
        compose.onNodeWithTag("exam.score").performTextReplacement("88.5"); compose.onNodeWithText("保存").performClick()
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().records.singleOrNull()?.exam?.score == 88.5 } }
        compose.waitUntil(5000) { compose.onAllNodesWithTag("exam.score").fetchSemanticsNodes().isEmpty() }; compose.waitForIdle()
        compose.onNodeWithTag("exam.row.$id").performScrollTo().performTouchInput { swipeLeft() }
        compose.onNodeWithContentDescription("删除成绩").performClick()
        compose.onNodeWithText("撤销").performClick()
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().records.singleOrNull()?.exam?.score == 88.5 } }
    }
    @Test fun allMainScreensRemainUsableWithGlassAndUserScopes() {
        onboard()
        runBlocking {
            val repo = testAccess().repository(); var state = repo.snapshot(); repo.saveSubject("数学","100",state.scope); state = repo.snapshot()
            repo.saveRecords((0 until 8).map { i -> ExamRecord(subjectId=state.subjects.single().id,examName="阶段练习 ${i+1}",examDate=RecordValidation.date("2026-10-${10+i}"),score=60.0+i*4,examType="月考",classRank=if(i%2 == 0) 20-i else null,userId=state.scope.user,semesterId=state.scope.semester) },state.scope)
            repo.preferences.setThemeStyle(AppThemeStyle.LIQUID_GLASS); repo.preferences.setGlassBlurRadiusDp(12f)
            val context = ApplicationProvider.getApplicationContext<Context>()
            val wallpaper = File(context.cacheDir,"synthetic-wallpaper.jpg")
            val bitmap = android.graphics.Bitmap.createBitmap(720,1280,android.graphics.Bitmap.Config.ARGB_8888)
            val paint = android.graphics.Paint().apply { shader = android.graphics.LinearGradient(0f,0f,720f,1280f,intArrayOf(android.graphics.Color.rgb(64,102,166),android.graphics.Color.rgb(214,158,120),android.graphics.Color.rgb(204,214,191)),floatArrayOf(0f,0.55f,1f),android.graphics.Shader.TileMode.CLAMP) }
            android.graphics.Canvas(bitmap).drawPaint(paint); wallpaper.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,90,it) }; bitmap.recycle()
            repo.preferences.setCustomWallpaperUri(repo.saveImage(android.net.Uri.fromFile(wallpaper),false))
        }
        compose.waitUntil(10000) { compose.onAllNodesWithText("8 次记录",substring=true).fetchSemanticsNodes().isNotEmpty() }
        compose.waitForIdle(); image("04-home-glass")
        compose.onNodeWithTag("tab.1").performClick(); compose.onNodeWithText("给努力，一个归属。").assertIsDisplayed(); image("05-subjects")
        compose.onNodeWithTag("tab.2").performClick(); waitTag("analysis.chart"); image("06-analysis-multiple-exams")
        compose.onNodeWithTag("tab.3").performClick(); compose.onNodeWithText("数据与备份").performScrollTo().performClick(); compose.onNodeWithText("完整备份",substring=false).performScrollTo().assertIsDisplayed(); image("07-data")
        compose.onNodeWithTag("navigation.back").performClick(); compose.onNodeWithText("学习阶段",substring=false).performScrollTo().performClick(); compose.onNodeWithTag("stage.university").performClick(); compose.onNodeWithText("开启大学阶段").performClick()
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().semester?.schoolTerm?.stage == SchoolStage.UNIVERSITY } }
        compose.onNodeWithTag("tab.0").performClick(); compose.onNodeWithTag("home.add").assertIsDisplayed(); image("08-university-empty")
    }
    @Test fun batchAndUnsavedDraftCompleteThroughTheVisibleEditors() {
        onboard()
        runBlocking { val repo=testAccess().repository(); val s=repo.snapshot(); repo.saveSubject("数学","100",s.scope); repo.saveSubject("语文","100",s.scope) }
        compose.waitUntil(10000) { compose.onAllNodesWithText("2 科 · 0 次记录").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("一次考试，多科录入").performScrollTo().performClick(); waitTag("batch.score.0")
        compose.onNodeWithContentDescription("考试名称").performScrollTo().performTextInput("整场考试")
        compose.onNodeWithTag("batch.score.0").performScrollTo().performTextInput("82.5")
        compose.onNodeWithText("添加一行").performScrollTo().performClick()
        compose.onNodeWithTag("batch.score.1").performScrollTo().performTextInput("91")
        compose.onNodeWithText("保存全部").performClick()
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().records.size==2 } }
        compose.onNodeWithTag("home.add").performScrollTo().performClick(); waitTag("exam.score")
        compose.onNodeWithTag("exam.score").performScrollTo().performTextInput("88")
        compose.onNodeWithText("取消").performClick(); compose.onNodeWithText("保留草稿并关闭").performClick()
        compose.waitUntil(10000) { runBlocking { testAccess().repository().database.platformMetadataDao().get("draft:exam:${testAccess().repository().snapshot().scope.user}:${testAccess().repository().snapshot().scope.semester}:0")?.contains("88")==true } }
        compose.onNodeWithTag("home.add").performScrollTo().performClick(); compose.waitUntil(10000) { compose.onAllNodesWithText("继续编辑草稿").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("继续编辑草稿").performClick(); compose.onNodeWithTag("exam.score").assertTextEquals("88")
        compose.onNodeWithText("保存").performClick()
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().records.size==3 } }
        image("09-batch-and-draft")
    }
    @Test fun darkAppearanceAndEditorRemainUsableAtAnyFontSize() {
        onboard()
        runBlocking { val repo=testAccess().repository(); val s=repo.snapshot(); repo.saveSubject("数学","100",s.scope); repo.preferences.setAppearance(mode="dark") }
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().preferences.displayMode=="dark" } }
        image("10-home-dark")
        compose.onNodeWithTag("home.add").performScrollTo().performClick(); waitTag("exam.score")
        compose.onNodeWithTag("exam.score").performScrollTo().performTextInput("86.25")
        compose.waitUntil(10000) {
            val view=compose.activity.window.decorView
            val keyboard=androidx.core.view.ViewCompat.getRootWindowInsets(view)?.getInsets(androidx.core.view.WindowInsetsCompat.Type.ime())?.bottom ?: 0
            val field=compose.onNodeWithTag("exam.score").fetchSemanticsNode()
            keyboard>0 && field.boundsInWindow.height>=field.size.height-1 && field.boundsInWindow.bottom<=view.height-keyboard
        }
        android.os.SystemClock.sleep(1500)
        image("11-editor-dark")
        val save=compose.onNodeWithText("保存").fetchSemanticsNode()
        Assert.assertTrue("Save action is clipped: ${save.boundsInWindow}, original size ${save.size}",save.size.height>0 && save.boundsInWindow.height>=save.size.height-1 && save.boundsInWindow.top>=0)
        val now=android.os.SystemClock.uptimeMillis(); val bounds=save.boundsInWindow
        val down=android.view.MotionEvent.obtain(now,now,android.view.MotionEvent.ACTION_DOWN,bounds.center.x,bounds.center.y,0)
        val up=android.view.MotionEvent.obtain(now,now+80,android.view.MotionEvent.ACTION_UP,bounds.center.x,bounds.center.y,0)
        down.source=android.view.InputDevice.SOURCE_TOUCHSCREEN; up.source=android.view.InputDevice.SOURCE_TOUCHSCREEN
        try { val automation=InstrumentationRegistry.getInstrumentation().uiAutomation; Assert.assertTrue(automation.injectInputEvent(down,true)); Assert.assertTrue(automation.injectInputEvent(up,true)) }
        finally { down.recycle(); up.recycle() }
        compose.waitUntil(10000) { runBlocking { testAccess().repository().snapshot().records.size==1 } }
        compose.onNodeWithTag("tab.2").performClick(); waitTag("analysis.chart"); compose.onNodeWithTag("analysis.chart").performScrollTo().assertIsDisplayed(); image("12-analysis-dark")
    }
    @Test fun nativeFilesPickerSelectsAnActualXLSXAndImportsItsPreview() {
        onboard()
        val instrumentation=InstrumentationRegistry.getInstrumentation(); val context=ApplicationProvider.getApplicationContext<Context>()
        val filename="studytrack-picker-${System.currentTimeMillis()}.xlsx"
        val values=android.content.ContentValues().apply { put(android.provider.MediaStore.Downloads.DISPLAY_NAME,filename); put(android.provider.MediaStore.Downloads.MIME_TYPE,"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"); put(android.provider.MediaStore.Downloads.RELATIVE_PATH,"Download") }
        val uri=context.contentResolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,values)!!
        context.contentResolver.openOutputStream(uri)!!.use { output -> instrumentation.context.assets.open("android-poi.xlsx").use { it.copyTo(output) } }
        val expected=com.repea.studytrack.utils.ExcelHelper(context).readPreview(uri).records.size
        Assert.assertTrue(expected>0)
        compose.onNodeWithTag("tab.3").performClick(); compose.onNodeWithText("数据与备份").performScrollTo().performClick()
        compose.onNodeWithText("导入 .xlsx").performScrollTo().performClick()
        var selected=false; val deadline=android.os.SystemClock.uptimeMillis()+30000
        while(!selected && android.os.SystemClock.uptimeMillis()<deadline) {
            val node=instrumentation.uiAutomation.rootInActiveWindow?.findAccessibilityNodeInfosByText(filename)?.firstOrNull()
            if(node!=null) {
                // Android 10's DocumentsUI row does not reliably expose ACTION_CLICK.
                val bounds=android.graphics.Rect(); node.getBoundsInScreen(bounds)
                val now=android.os.SystemClock.uptimeMillis()
                val down=android.view.MotionEvent.obtain(now,now,android.view.MotionEvent.ACTION_DOWN,bounds.exactCenterX(),bounds.exactCenterY(),0)
                val up=android.view.MotionEvent.obtain(now,now+80,android.view.MotionEvent.ACTION_UP,bounds.exactCenterX(),bounds.exactCenterY(),0)
                down.source=android.view.InputDevice.SOURCE_TOUCHSCREEN; up.source=android.view.InputDevice.SOURCE_TOUCHSCREEN
                try { selected=instrumentation.uiAutomation.injectInputEvent(down,true) && instrumentation.uiAutomation.injectInputEvent(up,true) }
                finally { down.recycle(); up.recycle() }
            }
            if(!selected) android.os.SystemClock.sleep(300)
        }
        if(!selected) image("failure-native-picker")
        Assert.assertTrue("Native Files picker did not expose the synthetic workbook",selected)
        waitTag("data.import.confirm"); image("13-native-xlsx-preview")
        compose.onNodeWithTag("data.import.confirm").performScrollTo().performClick()
        compose.waitUntil(15000) { runBlocking { testAccess().repository().snapshot().allRecords.size==expected } }
        image("14-native-xlsx-imported")
        context.contentResolver.delete(uri,null,null)
    }
}
