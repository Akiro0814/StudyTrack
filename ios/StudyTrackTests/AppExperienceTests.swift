#if canImport(UIKit) && canImport(StudyTrack)
import XCTest
import UIKit
@testable import StudyTrack
import StudyTrackCore

final class AppExperienceTests: XCTestCase {
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
