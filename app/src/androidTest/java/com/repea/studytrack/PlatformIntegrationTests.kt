package com.repea.studytrack

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import com.repea.studytrack.data.local.entity.*
import com.repea.studytrack.domain.*
import com.repea.studytrack.repository.*
import com.repea.studytrack.utils.*
import com.repea.studytrack.widget.WidgetOptions
import kotlinx.coroutines.runBlocking
import org.junit.*
import org.junit.Assert.*
import java.io.File
import java.time.ZoneId

class PlatformIntegrationTests {
    @Before fun reset() { clearFixture() }
    private suspend fun seed(): PlatformRepository {
        val repo = testAccess().repository(); repo.createProfile("甲",SchoolTerm(SchoolStage.HIGH,1,1),true)
        val s = repo.snapshot(); repo.saveSubject("数学","100",s.scope)
        val current = repo.snapshot(); repo.saveRecords(listOf(ExamRecord(subjectId=current.subjects.single().id,examName="期中测试",examDate=RecordValidation.date("2026-10-24"),score=85.25,examType="期中",classRank=12,reflection="检查计算",userId=current.scope.user,semesterId=current.scope.semester)),current.scope)
        return repo
    }
    @Test fun nextSemesterInheritsSubjectsAndWholeStageKeepsHistory() = runBlocking {
        val repo = seed(); val first = repo.snapshot()
        repo.saveTerm(SchoolTerm(SchoolStage.HIGH,1,2),first.scope)
        val second = repo.snapshot(); assertEquals(0,second.records.size); assertEquals(1,second.subjects.size)
        assertEquals(first.subjects.single().lineageId,second.subjects.single().lineageId)
        assertEquals(1,second.analysis(true).single().records.size)
        repo.saveTerm(SchoolTerm(SchoolStage.UNIVERSITY,1,1),second.scope)
        assertTrue(repo.snapshot().subjects.isEmpty()); assertTrue(repo.snapshot().analysis(true).isEmpty())
    }
    @Test fun invalidBatchRollsBackEveryRow() = runBlocking {
        val repo = seed(); val state = repo.snapshot(); val subject = state.subjects.single()
        val records = listOf(90.0,101.0).mapIndexed { i,score -> ExamRecord(subjectId=subject.id,examName="批量$i",examDate=RecordValidation.date("2026-10-25"),score=score,examType="月考",userId=state.scope.user,semesterId=state.scope.semester) }
        try { repo.saveRecords(records,state.scope); fail("invalid batch accepted") } catch(_: IllegalArgumentException) {}
        assertEquals(1,repo.snapshot().records.size)
    }
    @Test fun duplicateSubjectNeverReplacesExistingScores() = runBlocking {
        val repo = seed(); val state = repo.snapshot()
        try { repo.saveSubject("数学","150",state.scope); fail("duplicate accepted") } catch(_: IllegalArgumentException) {}
        assertEquals(1,repo.snapshot().records.size); assertEquals(100.0,repo.snapshot().subjects.single().fullScore,0.0)
    }
    @Test fun widgetsHideOtherUsersAndRejectStaleScopes() = runBlocking {
        val repo = seed(); val first = repo.snapshot()
        repo.preferences.setMultiUserEnabled(true); repo.createProfile("乙",SchoolTerm(SchoolStage.JUNIOR,1,1),false)
        val second = repo.snapshot(); repo.saveSubject("物理","70",second.scope); repo.preferences.setMultiUserEnabled(false)
        val current = repo.snapshot(); val choices = WidgetOptions.make(current)
        assertTrue(choices.all { it.userID == current.scope.user }); assertTrue(current.records.isEmpty())
        try { repo.saveSubject("旧范围","100",first.scope); fail("stale scope accepted") } catch(_: IllegalArgumentException) {}
        try { repo.select(first.scope); fail("single-user scope switch accepted") } catch(_: IllegalArgumentException) {}
    }
    @Test fun backupRoundTripIncludesAvatarAppearanceAndRollback() = runBlocking {
        val repo = seed(); val context = ApplicationProvider.getApplicationContext<Context>()
        val image = File(context.cacheDir,"synthetic-avatar.png")
        val bitmap = Bitmap.createBitmap(16,16,Bitmap.Config.ARGB_8888); bitmap.eraseColor(android.graphics.Color.BLUE)
        image.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG,100,it) }; bitmap.recycle()
        val saved = repo.saveImage(Uri.fromFile(image),true); var state = repo.snapshot(); repo.renameUser(state.user!!,"甲",saved)
        repo.preferences.setAppearance(mode="dark",accent="#9C5CD1"); state = repo.snapshot()
        val file = File(context.cacheDir,"roundtrip.studytrackbackup"); testAccess().exporter().export(Uri.fromFile(file),ZoneId.systemDefault().id)
        val archive = BackupArchive.decode(file.readBytes()); assertEquals(1,archive.data.getJSONArray("assets").length())
        val backups = testAccess().backups(); val preview = backups.inspect(Uri.fromFile(file)); backups.restore(preview)
        val restored = repo.snapshot(); assertEquals("甲",restored.user?.name); assertEquals(85.25,restored.records.single().exam.score,0.0)
        assertEquals("dark",restored.preferences.displayMode); assertNotNull(restored.user?.avatarUri); assertEquals(SchoolTerm(SchoolStage.HIGH,1,1),restored.semester?.schoolTerm)
        assertTrue(File(backups.latestRecovery().path!!).exists())
        val secondFile = File(context.cacheDir,"roundtrip-after.studytrackbackup"); testAccess().exporter().export(Uri.fromFile(secondFile),ZoneId.systemDefault().id)
        val again = BackupArchive.decode(secondFile.readBytes()); assertEquals(archive.data.getJSONArray("users").getJSONObject(0).getString("id"),again.data.getJSONArray("users").getJSONObject(0).getString("id"))
    }
    @Test fun restorePreviewBecomesInvalidAfterDataChanges() = runBlocking {
        val repo = seed(); val context = ApplicationProvider.getApplicationContext<Context>(); val file = File(context.cacheDir,"stale.studytrackbackup")
        testAccess().exporter().export(Uri.fromFile(file),ZoneId.systemDefault().id)
        val preview = testAccess().backups().inspect(Uri.fromFile(file)); val state = repo.snapshot(); repo.renameUser(state.user!!,"新名字")
        try { testAccess().backups().restore(preview); fail("stale restore accepted") } catch(_: IllegalArgumentException) {}
        assertEquals("新名字",repo.snapshot().user?.name)
    }
    @Test fun invalidImportDoesNotSwitchSemesterOrLeavePartialRows() = runBlocking {
        val repo = seed(); val state = repo.snapshot()
        val rows = listOf(ParsedRecord("数学","高一下学期","有效行",RecordValidation.date("2026-10-25"),80.0,100.0,"月考",null,null,null,null),ParsedRecord("数学","高一下学期","错误行",RecordValidation.date("2026-10-26"),150.0,100.0,"月考",null,null,null,null))
        try { repo.importRecords(rows,state.scope); fail("bad import accepted") } catch(_: IllegalArgumentException) {}
        val next = repo.snapshot(); assertEquals(state.scope,next.scope); assertEquals(1,next.semesters.size); assertEquals(1,next.records.size)
    }
    @Test fun pendingRestorePreferencesSurviveAnInterruptedCommit() = runBlocking {
        val repo = seed(); val original = repo.snapshot()
        repo.preferences.setMultiUserEnabled(true); repo.createProfile("恢复目标",SchoolTerm(SchoolStage.UNIVERSITY,1,1),false)
        val restored = repo.snapshot()
        repo.preferences.selectScope(original.scope.user,original.scope.semester)
        repo.database.platformMetadataDao().put(PlatformMetadata("pendingPreferences",PreferenceStateCodec.encode(restored.preferences)))
        testAccess().backups().completePendingRestore()
        assertEquals(restored.scope,repo.snapshot().scope)
        assertNull(repo.database.platformMetadataDao().get("pendingPreferences"))
    }
}
