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
    var homeAnalysis = AnalysisData()
    var recentlyDeleted: Exam?
    var analysisRoute: WidgetAnalysisRoute?
    func deleteRecord(_ exam: Exam) async {
        guard let store, let current = scope, current.userID == exam.userID else { return }
        if await perform({
            guard scope == current else { throw StudyError.scopeChanged }
            try await store.deleteExam(id: exam.id,scope: StudyScope(userID: exam.userID,semesterID: exam.semesterID))
        }) { recentlyDeleted = exam }
    }
    func undoDeletion() async {
        guard let exam = recentlyDeleted, exam.userID == scope?.userID else { recentlyDeleted = nil; return }
        if await perform({ try await store?.restoreExam(exam) }) { recentlyDeleted = nil }
    }
    var scope: StudyScope? { preferences.scope }
    var currentUser: User? { users.first { $0.id == preferences.currentUserID } }
    var currentSemester: Semester? { semesters.first { $0.id == preferences.currentSemesterID } }
    var selectionRevision = 0
    var dataRevision = 0
    var wallpaper: UIImage?
    var avatar: UIImage?
    private var loadedAvatarID: String?
    private var loadedWallpaperID: String?
    private var loadedWallpaperRevision = -1
    var accent: Color {
        if let rgb = RGBColor.parse(preferences.accent) { return Color(red: Double(rgb.red)/255,green: Double(rgb.green)/255,blue: Double(rgb.blue)/255) }
        switch preferences.accent {
        case "green": return Color(red: 0.10,green: 0.56,blue: 0.44)
        case "orange": return Color(red: 0.88,green: 0.32,blue: 0.24)
        case "purple": return Color(red: 0.61,green: 0.36,blue: 0.82)
        default: return Color(red: 0.29,green: 0.40,blue: 0.91)
        }
    }
    func start() async {
        guard !ready else { return }
        do {
            let base: URL
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uitesting") }) {
                base = FileManager.default.temporaryDirectory.appendingPathComponent("StudyTrack-UI-\(UUID().uuidString)")
            } else { base = try FileManager.default.url(for: .applicationSupportDirectory,in: .userDomainMask,appropriateFor: nil,create: true).appendingPathComponent("StudyTrack") }
            #else
            base = try FileManager.default.url(for: .applicationSupportDirectory,in: .userDomainMask,appropriateFor: nil,create: true).appendingPathComponent("StudyTrack")
            #endif
            try FileManager.default.createDirectory(at: base,withIntermediateDirectories: true)
            store = try StudyStore(path: base.appendingPathComponent("studytrack.sqlite").path)
            files = FileService(root: base)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitesting-showcase") { try await seedExperiencePreview() }
            #endif
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
        var overview = AnalysisData()
        if let selected = p.scope { overview = try await store.analysis(scope: selected,wholeStage: false) }
        guard revision == selectionRevision else { return }
        preferences = p; users = u; semesters = terms; subjects = subs; home = page
        homeAnalysis = overview
        dataRevision = try await store.revision()
        let avatarID = p.currentUserID.flatMap { p.avatarAssetID(for: $0) }
        if p.wallpaperAssetID != loadedWallpaperID || avatarID != loadedAvatarID || loadedWallpaperRevision != selectionRevision {
            let assets = try await store.snapshot().assets
            func image(_ id: String?) async -> UIImage? {
                guard let id, let asset = assets.first(where: { $0.id == id }), let files,
                      let data = try? await files.wallpaper(asset) else { return nil }
                return UIImage(data: data)
            }
            wallpaper = await image(p.wallpaperAssetID)
            avatar = await image(avatarID)
            loadedAvatarID = avatarID
            loadedWallpaperID = p.wallpaperAssetID
            loadedWallpaperRevision = selectionRevision
        }
        await publishWidgets()
    }
    @discardableResult func perform(onError: ((String) -> Void)? = nil, _ action: () async throws -> Void) async -> Bool {
        guard !busy else { return false }; busy = true; defer { busy = false }
        do { try await action(); try await reload(); return true }
        catch { if let onError { onError(friendly(error)) } else { self.error = friendly(error) }; return false }
    }
    func switchScope(_ target: StudyScope) async {
        _ = await perform {
            guard let store else { return }; try await store.select(target); selectionRevision += 1
            recentlyDeleted = nil
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
