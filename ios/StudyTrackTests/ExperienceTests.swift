import XCTest
@testable import StudyTrackCore

final class ExperienceTests: XCTestCase {
    func testSameDayExamsHaveDistinctStablePositionsAndRanksKeepGaps() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "Student",semester: "Fall")
        let subject = try await store.saveSubject(id: nil,name: "Math",fullScore: 10000,scope: scope)
        _ = try await store.saveExams([
            ExamInput(subjectID: subject.id,name: "A",date: try LocalDate("2026-10-14"),score: 4500,classRank: 12),
            ExamInput(subjectID: subject.id,name: "B",date: try LocalDate("2026-10-14"),score: 7900),
            ExamInput(subjectID: subject.id,name: "C",date: try LocalDate("2026-10-14"),score: 6300,classRank: 8)
        ],scope: scope)
        let rows = try await store.exams(scope: scope,filter: ExamFilter(),offset: 0,limit: 50).rows
        let points = ExamTimeline.points(rows,metric: .score)
        XCTAssertEqual(points.map(\.position),[1,2,3])
        XCTAssertEqual(Set(points.map(\.id)).count,3)
        XCTAssertEqual(points.map(\.id),ExamTimeline.points(Array(rows.reversed()),metric: .score).map(\.id))
        let ranks = ExamTimeline.points(rows,metric: .classRank)
        XCTAssertEqual(ranks.count,2)
        XCTAssertTrue(ranks.allSatisfy { $0.value > 0 })
        XCTAssertEqual(ranks.map(\.position),points.filter { $0.exam.classRank != nil }.map(\.position))
        XCTAssertEqual(ExamTimeline.points([],metric: .score).count,0)
        XCTAssertEqual(ExamTimeline.points([rows[0]],metric: .score).first?.position,1)
    }

    func testAvatarIsScopedPersistentAndIncludedInBackup() async throws {
        let store = try StudyStore(path: ":memory:")
        let first = try await store.createUser(name: "A",semester: "Fall")
        let second = try await store.createUser(name: "B",semester: "Fall")
        let bytes = Data("avatar-fixture".utf8)
        let id = UUID().uuidString.lowercased()
        _ = try await store.addAsset(Asset(id: id,relativePath: "assets/avatar.jpg",mimeType: "image/jpeg",sha256: SafeArchive.sha256(bytes),byteCount: bytes.count))
        var preferences = try await store.preferences()
        preferences.platformExtensions["android"] = .object(["keep": .bool(true)])
        preferences.setAvatarAssetID(id,for: first.userID)
        try await store.updatePreferences(preferences)
        let snapshot = try await store.snapshot()
        let backup = try BackupCodec.decode(BackupCodec.encode(snapshot,resources: ["assets/avatar.jpg": bytes]))
        XCTAssertEqual(backup.snapshot.preferences.avatarAssetID(for: first.userID),id)
        XCTAssertNil(backup.snapshot.preferences.avatarAssetID(for: second.userID))
        XCTAssertEqual(backup.snapshot.preferences.platformExtensions["android"],.object(["keep": .bool(true)]))
        preferences.setAvatarAssetID(UUID().uuidString.lowercased(),for: second.userID)
        do { try await store.updatePreferences(preferences); XCTFail("Missing avatar resource accepted") } catch {}
        try await store.deleteUser(id: first.userID)
        let repaired = try await store.preferences()
        XCTAssertNil(repaired.avatarAssetID(for: first.userID))
    }
}
