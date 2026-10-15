import SwiftUI
import WidgetKit
import StudyTrackCore

extension AppModel {
    func publishWidgets() async {
        guard let store, let url = WidgetArchive.fileURL else { return }
        do {
            let snapshot = try await store.snapshot()
            let archive = await Task.detached { WidgetArchive.make(snapshot) }.value
            let data = try JSONEncoder().encode(archive)
            try data.write(to: url,options: [.atomic,.completeFileProtectionUnlessOpen])
            WidgetCenter.shared.reloadAllTimelines()
        } catch { /* A widget capability failure must not prevent local grade editing. */ }
    }
    func openWidget(_ url: URL) async {
        guard url.scheme == "studytrack",url.host == "analysis",let components = URLComponents(url: url,resolvingAgainstBaseURL: false) else { return }
        let values = Dictionary(components.queryItems?.map { ($0.name,$0.value ?? "") } ?? [],uniquingKeysWith: { first,_ in first })
        if values.isEmpty { analysisRoute = WidgetAnalysisRoute(subjectID: nil,wholeStage: false); return }
        guard let user = values["user"],let semester = values["semester"],preferences.multiUserEnabled || user == preferences.currentUserID,
              let store,let terms = try? await store.semesters(userID: user),terms.contains(where: { $0.id == semester }) else { notice = "小组件对应的档案已不可用。"; return }
        await switchScope(StudyScope(userID: user,semesterID: semester))
        analysisRoute = WidgetAnalysisRoute(subjectID: values["subject"],wholeStage: values["stage"] == "1")
    }
}
struct WidgetAnalysisRoute: Equatable {
    var requestID = UUID()
    var subjectID: String?
    var wholeStage: Bool
}
