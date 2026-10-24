import XCTest
@testable import StudyTrackCore

final class WidgetReliabilityTests: XCTestCase {
    func testDefaultWidgetPrefersRecordedSubjectAndMostRecentExam() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createProfile(name: "测试学生",term: SchoolTerm(stage: .high,year: 1,half: 1),avatar: nil)
        _ = try await store.saveSubject(id: nil,name: "A 空科目",fullScore: 10000,scope: scope)
        let old = try await store.saveSubject(id: nil,name: "B 旧成绩",fullScore: 10000,scope: scope)
        let latest = try await store.saveSubject(id: nil,name: "C 新成绩",fullScore: 10000,scope: scope)
        _ = try await store.saveExams([ExamInput(subjectID: old.id,name: "旧考试",date: LocalDate("2026-09-01"),score: 7000),ExamInput(subjectID: latest.id,name: "新考试",date: LocalDate("2026-10-01"),score: 8500)],scope: scope)
        let archive = WidgetArchive.make(try await store.snapshot())
        XCTAssertEqual(archive.series.first { $0.id == archive.defaultID }?.subjectID,latest.id)
        XCTAssertEqual(archive.series.first { $0.id == archive.defaultID }?.scores.last,8500)
    }

    func testWidgetOrderingIsStableAndDeletedSubjectDisappears() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createProfile(name: "学生",term: SchoolTerm(stage: .high,year: 1,half: 1),avatar: nil)
        let subject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        let before = WidgetArchive.make(try await store.snapshot())
        let repeated = WidgetArchive.make(try await store.snapshot())
        XCTAssertEqual(before.series.map(\.id),repeated.series.map(\.id))
        try await store.deleteSubject(id: subject.id,scope: scope)
        let after = WidgetArchive.make(try await store.snapshot())
        XCTAssertNil(after.defaultID)
        XCTAssertTrue(after.series.isEmpty)
    }
}
