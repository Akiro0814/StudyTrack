import SwiftUI
import WidgetKit
import StudyTrackCore

extension AppModel {
    func scheduleWidgetUpdate() {
        widgetUpdateTask?.cancel()
        widgetGeneration += 1
        guard let store, let url = WidgetArchive.fileURL else { return }
        let generation = widgetGeneration, publisher = widgetPublisher
        widgetUpdateTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                let snapshot = try await store.snapshot()
                try Task.checkCancellation()
                if try await publisher.publish(snapshot,to: url,generation: generation) { WidgetCenter.shared.reloadAllTimelines() }
                widgetStatus = nil
            } catch is CancellationError { }
            catch { widgetStatus = "小组件刷新失败，请重新打开应用后重试。" }
        }
    }
    func publishWidgetsNow() async {
        widgetUpdateTask?.cancel()
        widgetGeneration += 1
        guard let store else { return }
        guard let url = WidgetArchive.fileURL else {
            widgetStatus = "当前安装没有可用的共享容器。请使用同时保留 App Group 和小组件扩展签名的安装包。"
            return
        }
        let generation = widgetGeneration
        do {
            let snapshot = try await store.snapshot()
            if try await widgetPublisher.publish(snapshot,to: url,generation: generation) { WidgetCenter.shared.reloadAllTimelines() }
            widgetStatus = nil
        } catch { widgetStatus = "小组件刷新失败，请重新打开应用后重试。" }
    }
    func openWidget(_ url: URL) async {
        guard url.scheme == "studytrack",url.host == "analysis",let components = URLComponents(url: url,resolvingAgainstBaseURL: false) else { return }
        let values = Dictionary(components.queryItems?.map { ($0.name,$0.value ?? "") } ?? [],uniquingKeysWith: { first,_ in first })
        if values.isEmpty { analysisRoute = WidgetAnalysisRoute(subjectID: nil,wholeStage: false); return }
        guard let user = values["user"],let semester = values["semester"],preferences.multiUserEnabled || user == preferences.currentUserID,
              let store,let terms = try? await store.semesters(userID: user),terms.contains(where: { $0.id == semester }) else { notice = "小组件对应的档案已不可用。"; return }
        let target = StudyScope(userID: user,semesterID: semester)
        if let subject = values["subject"] {
            let data = try? await store.analysis(scope: target,wholeStage: values["stage"] == "1")
            guard data?.subjects.contains(where: { $0.id == subject }) == true else { notice = "小组件对应的科目已删除，请长按小组件重新选择。"; return }
        }
        if scope != target { await switchScope(target) }
        guard scope == target else { return }
        analysisRoute = WidgetAnalysisRoute(subjectID: values["subject"],wholeStage: values["stage"] == "1")
    }
}

/// Serial background writes and generation checks prevent an older export from
/// replacing the result of a newer delete, user switch, or restore.
actor WidgetPublisher {
    private var writtenGeneration = -1
    func publish(_ snapshot: Snapshot,to url: URL,generation: Int) throws -> Bool {
        guard generation > writtenGeneration else { return false }
        try Task.checkCancellation()
        let data = try JSONEncoder().encode(WidgetArchive.make(snapshot))
        try Task.checkCancellation()
        // WidgetKit must be able to open a new read while the device is locked,
        // after its first unlock. Sensitive views still obey WidgetKit redaction.
        try data.write(to: url,options: [.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        writtenGeneration = generation; return true
    }
}
struct WidgetAnalysisRoute: Equatable {
    var requestID = UUID()
    var subjectID: String?
    var wholeStage: Bool
}
