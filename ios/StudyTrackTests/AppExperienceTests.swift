#if canImport(UIKit) && canImport(StudyTrack)
import XCTest
import UIKit
@testable import StudyTrack
import StudyTrackCore

final class AppExperienceTests: XCTestCase {
    func testBackupFolderAuthorizationPersistsAcrossServiceInstances() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let key = "test.backup-folder.\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root); UserDefaults.standard.removeObject(forKey: key) }
        let first = CloudBackupService(bookmarkKey: key)
        try await first.authorize(root)
        try await first.upload(Data("persisted backup".utf8))
        let reopened = CloudBackupService(bookmarkKey: key)
        let destination = try await reopened.destination()
        XCTAssertEqual(destination?.url.resolvingSymlinksInPath().path,root.resolvingSymlinksInPath().path)
        let list = try await reopened.list()
        XCTAssertEqual(list.count,1)
        let bytes = try await reopened.download(list[0])
        XCTAssertEqual(bytes,Data("persisted backup".utf8))
    }
    func testOlderWidgetExportCannotReplaceNewerContent() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("widget-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createProfile(name: "旧名字",term: SchoolTerm(stage: .high,year: 1,half: 1),avatar: nil)
        _ = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        let old = try await store.snapshot()
        try await store.renameUser(id: scope.userID,name: "新名字")
        let new = try await store.snapshot()
        let publisher = WidgetPublisher()
        let latest = try await publisher.publish(new,to: url,generation: 2)
        let stale = try await publisher.publish(old,to: url,generation: 1)
        XCTAssertTrue(latest); XCTAssertFalse(stale)
        let archive = try JSONDecoder().decode(WidgetArchive.self,from: Data(contentsOf: url))
        XCTAssertTrue(archive.series.allSatisfy { $0.subtitle.contains("新名字") })
    }
    @MainActor func testDocumentPickerAcceptsGenericFilesAsCopiesAndFoldersInPlace() {
        let file = StudyDocumentPicker.makeController(for: .file)
        XCTAssertTrue(StudyDocumentPicker.Mode.file.asCopy)
        XCTAssertEqual(StudyDocumentPicker.Mode.file.contentTypes.map(\.identifier),["public.item"])
        XCTAssertFalse(file.allowsMultipleSelection)
        XCTAssertTrue(file.shouldShowFileExtensions)
        XCTAssertFalse(StudyDocumentPicker.Mode.folder.asCopy)
        XCTAssertEqual(StudyDocumentPicker.Mode.folder.contentTypes.map(\.identifier),["public.folder"])
    }
    func testBackupDirectoryRoundTripWithoutAppICloudContainer() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = CloudBackupService(testDirectory: root)
        let store = try StudyStore(path: ":memory:")
        _ = try await store.createProfile(name: "学生",term: SchoolTerm(stage: .high,year: 1,half: 1),avatar: nil)
        let snapshot = try await store.snapshot()
        let bytes = try BackupCodec.encode(snapshot,resources: [:])
        try await service.upload(bytes)
        let list = try await service.list()
        XCTAssertEqual(list.count,1)
        let downloaded = try await service.download(list[0])
        XCTAssertEqual(downloaded,bytes)
        let verified = try BackupCodec.decode(downloaded)
        XCTAssertEqual(verified.snapshot.users.first?.name,"学生")
    }
    @MainActor func testStageSwitchAndNextSemesterKeepExamsSeparate() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createProfile(name: "学生",term: SchoolTerm(stage: .high,year: 1,half: 1),avatar: nil)
        let subject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        _ = try await store.saveExams([ExamInput(subjectID: subject.id,name: "考试",date: LocalDate("2026-10-15"),score: 9000)],scope: scope)
        let model = AppModel(); model.store = store; try await model.reload()
        await model.openNextSemester()
        XCTAssertEqual(model.currentSemester?.schoolTerm,SchoolTerm(stage: .high,year: 1,half: 2))
        XCTAssertEqual(model.subjects.first?.name,"数学"); XCTAssertEqual(model.home.total,0)
        await model.switchStage(.university)
        XCTAssertEqual(model.currentSemester?.schoolTerm?.stage,.university)
        XCTAssertTrue(model.subjects.isEmpty)
        XCTAssertEqual(model.stageSemesters.count,1)
        await model.switchStage(.high)
        XCTAssertEqual(model.stageSemesters.count,2)
        XCTAssertTrue(model.stageSemesters.allSatisfy { $0.schoolTerm?.stage == .high })
    }
    @MainActor func testRapidAppearanceChangesPersistTheLastValue() async throws {
        let store = try StudyStore(path: ":memory:")
        _ = try await store.createUser(name: "A",semester: "高一上学期")
        let model = AppModel(); model.store = store; try await model.reload()
        var first = model.preferences; first.glassTint = 0.1
        var last = model.preferences; last.glassTint = 0.4; last.displayMode = "dark"
        let task = Task { await model.savePreferences(first) }
        await Task.yield()
        await model.savePreferences(last)
        await task.value
        let saved = try await store.preferences()
        XCTAssertEqual(saved.glassTint,0.4); XCTAssertEqual(saved.displayMode,"dark")
    }
    @MainActor func testImagesReloadAcrossThemesUserSwitchAndRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel()
        let store = try StudyStore(path: root.appendingPathComponent("test.sqlite").path)
        let files = FileService(root: root)
        model.store = store; model.files = files
        let first = try await store.createUser(name: "A",semester: "Fall")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80,height: 120)).image { context in
            UIColor.systemOrange.setFill(); context.fill(CGRect(x: 0,y: 0,width: 80,height: 120))
        }.pngData()!
        let wallpaperCandidate = try await files.saveWallpaper(image)
        let wallpaper = try await store.addAsset(wallpaperCandidate)
        let avatarCandidate = try await files.saveAvatar(image)
        let avatar = try await store.addAsset(avatarCandidate)
        var p = try await store.preferences()
        p.theme = "simple"; p.wallpaperAssetID = wallpaper.id; p.setAvatarAssetID(avatar.id,for: first.userID)
        try await store.updatePreferences(p); try await model.reload()
        XCTAssertNotNil(model.wallpaper); XCTAssertNotNil(model.avatar)
        p.theme = "glass"; try await store.updatePreferences(p); try await model.reload()
        XCTAssertNotNil(model.wallpaper)
        var multi = try await store.preferences(); multi.multiUserEnabled = true; try await store.updatePreferences(multi)
        let second = try await store.createUser(name: "B",semester: "Fall")
        model.selectionRevision += 1; try await model.reload()
        XCTAssertEqual(model.scope,second); XCTAssertNil(model.avatar); XCTAssertNotNil(model.wallpaper)
        try await store.select(first); model.selectionRevision += 1; try await model.reload()
        XCTAssertNotNil(model.avatar)
        p = try await store.preferences(); p.wallpaperAssetID = nil; p.setAvatarAssetID(nil,for: first.userID)
        try await store.updatePreferences(p); try await model.reload()
        XCTAssertNil(model.wallpaper); XCTAssertNil(model.avatar)
    }
}
#endif
