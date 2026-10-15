import XCTest
@testable import StudyTrackCore

final class SchoolSystemTests: XCTestCase {
    func testCatalogAndLegacyRecognition() throws {
        XCTAssertEqual(SchoolStage.allCases.flatMap { SchoolTerm.catalog(for: $0) }.count, 32)
        XCTAssertEqual(SchoolTerm.recognize("高一上学期"), SchoolTerm(stage: .high, year: 1, half: 1))
        XCTAssertNil(SchoolTerm.recognize("我的秋季"))
        XCTAssertEqual(SchoolTerm.catalog(for: .university).count, 8)
    }
    func testInheritanceDoesNotCopyExamsAndStageQueryIsIsolated() async throws {
        let store = try StudyStore(path: ":memory:")
        let first = try await store.createProfile(name: "甲", term: SchoolTerm(stage: .high, year: 1, half: 1), avatar: nil)
        let math = try await store.saveSubject(id: nil, name: "数学", fullScore: 10000, scope: first)
        _ = try await store.saveExams([ExamInput(subjectID: math.id, name: "考试", date: LocalDate("2026-10-01"), score: 9000)], scope: first)
        let secondID = try await store.saveSchoolSemester(term: SchoolTerm(stage: .high, year: 1, half: 2), userID: first.userID)
        let second = StudyScope(userID: first.userID, semesterID: secondID)
        let subjects = try await store.subjects(scope: second)
        XCTAssertEqual(subjects.count, 1)
        XCTAssertNotEqual(subjects.first?.id, math.id)
        XCTAssertEqual(subjects.first?.lineageID, math.lineageID)
        let empty = try await store.exams(scope: second, filter: ExamFilter())
        XCTAssertEqual(empty.total, 0)
        _ = try await store.saveExams([ExamInput(subjectID: subjects[0].id, name: "考试", date: LocalDate("2027-02-01"), score: 7000)], scope: second)
        let analysis = try await store.analysis(scope: second, wholeStage: true)
        XCTAssertEqual(analysis.exams.count, 2)
        XCTAssertEqual(analysis.groups.count, 1)
        XCTAssertEqual(analysis.groups[0].summary.average, 80)
        let junior = try await store.saveSchoolSemester(term: SchoolTerm(stage: .junior, year: 1, half: 1), userID: first.userID)
        let juniorSubjects = try await store.subjects(scope: StudyScope(userID: first.userID, semesterID: junior))
        XCTAssertTrue(juniorSubjects.isEmpty)
        let snapshot = try await store.snapshot()
        let restored = try StudyStore(path: ":memory:")
        try await restored.restore(BackupCodec.decode(BackupCodec.encode(snapshot, resources: [:])).snapshot)
        let terms = try await restored.semesters(userID: first.userID)
        XCTAssertEqual(terms.filter { $0.schoolTerm?.stage == .high }.count, 2)
    }
    func testSingleUserGuardAndFullSubjectSummary() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createProfile(name: "甲", term: SchoolTerm(stage: .primary, year: 1, half: 1), avatar: nil)
        do {
            _ = try await store.createProfile(name: "乙", term: SchoolTerm(stage: .primary, year: 1, half: 1), avatar: nil)
            XCTFail("disabled multi-user must reject a second profile")
        } catch StudyError.invalid {} 
        let math = try await store.saveSubject(id: nil, name: "数学", fullScore: 10000, scope: scope)
        for i in 0..<8 { _ = try await store.saveExams([ExamInput(subjectID: math.id, name: "考试\(i)", date: LocalDate("2026-10-01"), score: Int64(i * 1000))], scope: scope) }
        let data = try await store.analysis(scope: scope, wholeStage: false)
        XCTAssertEqual(data.groups[0].summary.count, 8)
        XCTAssertEqual(data.groups[0].summary.average, 35)
    }
}
