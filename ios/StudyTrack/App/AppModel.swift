import SwiftUI
import Observation
import StudyTrackCore

@MainActor @Observable
final class AppModel {
    var store: StudyStore?
    var files: FileService?
    var ready = false
    var busy = false
    var error: String?
    var notice: String?
    var preferences = Preferences()
    var users: [User] = []
    var semesters: [Semester] = []
    var subjects: [Subject] = []
    var home = ExamPage.empty
    var scope: StudyScope? { preferences.scope }
    var currentUser: User? { users.first { $0.id == preferences.currentUserID } }
    var currentSemester: Semester? { semesters.first { $0.id == preferences.currentSemesterID } }
    var selectionRevision = 0
    var wallpaper: UIImage?
    private var loadedWallpaperID: String?
    var accent: Color {
        switch preferences.accent { case "green": .green; case "orange": .orange; case "purple": .purple; default: .blue }
    }
    func start() async {
        guard !ready else { return }
        do {
            let base: URL
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitesting") {
                base = FileManager.default.temporaryDirectory.appendingPathComponent("StudyTrack-UI-\(UUID().uuidString)")
            } else { base = try FileManager.default.url(for: .applicationSupportDirectory,in: .userDomainMask,appropriateFor: nil,create: true).appendingPathComponent("StudyTrack") }
            #else
            base = try FileManager.default.url(for: .applicationSupportDirectory,in: .userDomainMask,appropriateFor: nil,create: true).appendingPathComponent("StudyTrack")
            #endif
            try FileManager.default.createDirectory(at: base,withIntermediateDirectories: true)
            store = try StudyStore(path: base.appendingPathComponent("studytrack.sqlite").path)
            files = FileService(root: base)
            try await reload(); ready = true
        } catch { self.error = "启动失败：\(friendly(error))" }
    }
    func reload() async throws {
        guard let store else { return }
        let revision = selectionRevision
        let p = try await store.preferences(), u = try await store.users()
        let terms = try await store.semesters(userID: p.currentUserID ?? "")
        var subs: [Subject] = [], page = ExamPage.empty
        if let scope = p.scope {
            subs = try await store.subjects(scope: scope)
            page = try await store.exams(scope: scope,filter: ExamFilter(),offset: 0,limit: 5)
        }
        guard revision == selectionRevision else { return }
        preferences = p; users = u; semesters = terms; subjects = subs; home = page
        if p.wallpaperAssetID != loadedWallpaperID {
            if let id = p.wallpaperAssetID, let snapshot = try? await store.snapshot(), let asset = snapshot.assets.first(where: { $0.id == id }), let data = try? await files?.wallpaper(asset) {
                wallpaper = UIImage(data: data)
            } else { wallpaper = nil }
            loadedWallpaperID = p.wallpaperAssetID
        }
    }
    @discardableResult func perform(onError: ((String) -> Void)? = nil, _ action: () async throws -> Void) async -> Bool {
        guard !busy else { return false }; busy = true; defer { busy = false }
        do { try await action(); try await reload(); return true }
        catch { if let onError { onError(friendly(error)) } else { self.error = friendly(error) }; return false }
    }
    func switchScope(_ target: StudyScope) async {
        _ = await perform {
            guard let store else { return }; try await store.select(target); selectionRevision += 1
        }
    }
    func savePreferences(_ value: Preferences) async {
        _ = await perform { try await store?.updatePreferences(value) }
    }
    func friendly(_ error: Error) -> String {
        if let error = error as? StudyError { return error.localizedDescription }
        if error is CancellationError { return "操作已取消。" }
        return "操作未完成，请重试。若仍失败，请先导出备份。"
    }
}

extension ExamPage {
    static var empty: ExamPage { ExamPage(rows: [],total: 0,summary: ExamSummary()) }
}
