package com.repea.studytrack.widget

import android.net.Uri
import com.repea.studytrack.domain.formatScore
import com.repea.studytrack.repository.*

data class WidgetOption(val id: String,val userID: Int,val semesterID: Int,val wholeStage: Boolean,val userName: String,val semesterName: String,val history: SubjectHistory) {
    val label get() = "$userName · $semesterName · ${history.subject.name} · ${formatScore(history.subject.fullScore)}分制"
    val deepLink: Uri get() = Uri.Builder().scheme("studytrack").authority("analysis").appendQueryParameter("user",userID.toString()).appendQueryParameter("semester",semesterID.toString()).appendQueryParameter("subject",history.subject.id.toString()).appendQueryParameter("stage",if(wholeStage) "1" else "0").build()
}
object WidgetOptions {
    fun make(state: PlatformState): List<WidgetOption> = state.users.filter { state.preferences.multiUserEnabled || it.id == state.scope.user }.flatMap { user ->
        state.semesters.filter { it.userId == user.id }.flatMap { term ->
            val selected = state.copy(preferences = state.preferences.copy(currentUserId = user.id,currentSemesterId = term.id))
            (if(term.schoolTerm != null) listOf(false,true) else listOf(false)).flatMap { whole -> selected.analysis(whole).map { group ->
                WidgetOption("${user.id}|${term.id}|$whole|${group.key}",user.id,term.id,whole,user.name,if(whole) term.schoolTerm?.stage?.label ?: term.name else term.name,group)
            } }
        }
    }.sortedBy { it.label + it.id }
    fun default(state: PlatformState,options: List<WidgetOption>): WidgetOption? {
        val current = options.filter { it.userID == state.scope.user && it.semesterID == state.scope.semester && !it.wholeStage }
        return current.filter { it.history.records.isNotEmpty() }.maxWithOrNull(compareBy({ it.history.records.last().exam.calendarDate() },{ it.history.records.last().exam.id })) ?: current.firstOrNull()
    }
}
