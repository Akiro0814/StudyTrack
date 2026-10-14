import XCTest
@testable import StudyTrackCore

final class ImportTests: XCTestCase {
    func testInvalidRowsCannotSeedSubjectsOrInflatePreviewCreationLists() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "甲",semester: "秋季")
        let date = try LocalDate("2026-10-12")
        let bad = ExchangeRow(row: 2,semester: "秋季",subject: "数学",name: "错误行",date: date,score: 20000,fullScore: nil,type: .other,classRank: nil,gradeRank: nil,districtRank: nil,reflection: nil)
        var good = bad; good.row = 3; good.score = 12000; good.fullScore = 15000; good.name = "有效行"
        var onlyBad = bad; onlyBad.row = 4; onlyBad.semester = "仅有错误的学期"; onlyBad.subject = "不应创建"
        let plan = try await store.previewImport(ParsedWorkbook(rows: [bad,good,onlyBad],issues: []),scope: scope,fileDigest: "test")
        XCTAssertEqual(plan.rows.count,1)
        XCTAssertTrue(plan.newSemesters.isEmpty)
        XCTAssertEqual(plan.newSubjects,["秋季 / 数学"])
        let report = try await store.commitImport(plan,validRowsOnly: true,acceptConversions: false)
        XCTAssertEqual(report.imported,1)
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.subjects.count,1); XCTAssertEqual(snapshot.subjects.first?.fullScore,15000)
    }
    func testImportAcrossSemestersPreservesSelectionAndReportsDuplicates() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "甲",semester: "秋季")
        let row = ExchangeRow(row: 2,semester: "春季",subject: "数学",name: "期中",date: try LocalDate("2026-03-20"),score: 12000,fullScore: 15000,type: .midterm,classRank: nil,gradeRank: 1,districtRank: nil,reflection: "中文")
        let parsed = ParsedWorkbook(rows: [row,row],issues: [])
        let plan = try await store.previewImport(parsed,scope: scope,fileDigest: "test")
        XCTAssertEqual(plan.rows.count,1); XCTAssertEqual(plan.duplicates,1)
        let report = try await store.commitImport(plan,validRowsOnly: false,acceptConversions: false)
        XCTAssertEqual(report.imported,1)
        let p = try await store.preferences()
        XCTAssertEqual(p.scope,scope)
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.exams.count,1); XCTAssertNotEqual(snapshot.exams.first?.semesterID,scope.semesterID)
        let again = try await store.previewImport(parsed,scope: scope,fileDigest: "test")
        XCTAssertEqual(again.rows.count,0); XCTAssertEqual(again.duplicates,2)
    }

    func testStalePreviewCannotCommit() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "甲",semester: "秋季")
        let row = ExchangeRow(row: 2,semester: "",subject: "数学",name: "月考",date: try LocalDate("2026-10-12"),score: 8500,fullScore: nil,type: .monthly,classRank: nil,gradeRank: nil,districtRank: nil,reflection: nil)
        let plan = try await store.previewImport(ParsedWorkbook(rows: [row],issues: []),scope: scope,fileDigest: "test")
        _ = try await store.saveSemester(name: "春季",userID: scope.userID)
        do { _ = try await store.commitImport(plan,validRowsOnly: false,acceptConversions: false); XCTFail("过期预览应失败") } catch {}
        let snapshot = try await store.snapshot(); XCTAssertTrue(snapshot.exams.isEmpty)
    }

    func testRestorePreservesUnknownAndroidExtensionsAndRejectsBrokenReferences() async throws {
        let store = try StudyStore(path: ":memory:")
        _ = try await store.createUser(name: "甲",semester: "秋季")
        var snapshot = try await store.snapshot()
        snapshot.preferences.platformExtensions = ["android": .object(["unknownSetting": .array([.bool(true),.number(1.25)])])]
        let backup = try BackupCodec.decode(BackupCodec.encode(snapshot,resources: [:]))
        try await store.restore(backup.snapshot)
        var p = try await store.preferences(); p.accent = "green"; try await store.updatePreferences(p)
        let second = try await store.snapshot()
        let roundTrip = try BackupCodec.decode(BackupCodec.encode(second,resources: [:]))
        XCTAssertEqual(roundTrip.snapshot.preferences.platformExtensions,snapshot.preferences.platformExtensions)
        var broken = second; broken.semesters[0].userID = UUID().uuidString.lowercased()
        do { try await store.restore(broken); XCTFail("外键损坏应失败") } catch {}
        let untouched = try await store.snapshot(); XCTAssertEqual(untouched.users.map(\.id),second.users.map(\.id))
    }

    func testUserDeletionRepairsSelectionAndLastUserCannotBeDeleted() async throws {
        let store = try StudyStore(path: ":memory:")
        let first = try await store.createUser(name: "甲",semester: "秋季")
        let second = try await store.createUser(name: "乙",semester: "秋季")
        try await store.deleteUser(id: second.userID)
        let preferences = try await store.preferences(); XCTAssertEqual(preferences.scope,first)
        do { try await store.deleteUser(id: first.userID); XCTFail("最后一个用户不能删除") } catch {}
    }
}
