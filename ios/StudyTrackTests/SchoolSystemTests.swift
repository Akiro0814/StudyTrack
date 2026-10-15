import XCTest
#if !canImport(UIKit)
import GRDB
#endif
@testable import StudyTrackCore

final class SchoolSystemTests: XCTestCase {
    func testProgressionStaysInStageAndFillsGapsBeforeAdvancing() {
        let high = SchoolTerm.catalog(for: .high)
        XCTAssertEqual(SemesterProgression.nextTerm(in: .high,existing: []),high[0])
        XCTAssertEqual(SemesterProgression.nextTerm(in: .high,existing: Array(high.prefix(2))),high[2])
        XCTAssertEqual(SemesterProgression.nextTerm(in: .high,existing: [high[0],high[5]]),high[1])
        XCTAssertEqual(SemesterProgression.nextTerm(in: .high,existing: SchoolTerm.catalog(for: .junior)),high[0])
        for stage in SchoolStage.allCases {
            XCTAssertNil(SemesterProgression.nextTerm(in: stage,existing: SchoolTerm.catalog(for: stage)))
        }
        XCTAssertEqual(SchoolStage.primary.next,.junior)
        XCTAssertEqual(SchoolStage.high.next,.university)
        XCTAssertNil(SchoolStage.university.next)
    }
    func testClassifyingLegacyTermJoinsUnambiguousSubjectHistory() async throws {
        let store = try StudyStore(path: ":memory:")
        let legacy = try await store.createUser(name: "学生",semester: "2026 秋")
        let oldSubject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: legacy)
        let nextID = try await store.saveSchoolSemester(term: SchoolTerm(stage: .high,year: 1,half: 2),userID: legacy.userID)
        let nextScope = StudyScope(userID: legacy.userID,semesterID: nextID)
        let newSubject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: nextScope)
        XCTAssertNotEqual(oldSubject.lineageID,newSubject.lineageID)
        _ = try await store.saveSchoolSemester(id: legacy.semesterID,term: SchoolTerm(stage: .high,year: 1,half: 1),userID: legacy.userID)
        let result = try await store.analysis(scope: legacy,wholeStage: true)
        XCTAssertEqual(result.groups.count,1)
        XCTAssertEqual(result.subjects.count,2)
    }
    func testMultiSubjectTimelineSeparatesSameDayAndBoundsRendering() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createProfile(name: "学生",term: SchoolTerm(stage: .high,year: 1,half: 1),avatar: nil)
        let subject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        let inputs = try (0..<600).map { ExamInput(subjectID: subject.id,name: "考试\($0)",date: try LocalDate("2026-10-01"),score: Int64($0 % 100)*100) }
        _ = try await store.saveExams(inputs,scope: scope)
        let data = try await store.analysis(scope: scope,wholeStage: false)
        let timeline = MultiSubjectTimeline(groups: data.groups,maximumPointsPerSubject: 100)
        XCTAssertEqual(timeline.all.count,600)
        XCTAssertEqual(Set(timeline.all.map(\.x)).count,600)
        XCTAssertGreaterThan(timeline.domain.lowerBound,10000)
        XCTAssertLessThan(timeline.domain.upperBound-timeline.domain.lowerBound,1)
        XCTAssertEqual(timeline.axisTicks.first?.label,"1")
        XCTAssertEqual(timeline.axisTicks.last?.label,"600")
        XCTAssertLessThanOrEqual(timeline.plotted.count,100)
        XCTAssertEqual(timeline.plotted.map(\.exam.score).max(),9900)
        XCTAssertEqual(data.groups[0].summary.count,600)
    }
    // Raw GRDB fixture preparation belongs to the standalone package test target.
    // Hosted iOS tests consume StudyTrackCore through the app's linked binary.
    #if !canImport(UIKit)
    func testUpgradeFromV1KeepsIDsAndRecords() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try StudyStore(path: path)
        let scope = try await store.createUser(name: "旧档案",semester: "高一上学期")
        let subject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        let exams = try await store.saveExams([ExamInput(subjectID: subject.id,name: "旧成绩",date: LocalDate("2026-10-01"),score: 8500)],scope: scope)
        let queue = try DatabaseQueue(path: path)
        try await queue.write { db in
            try db.execute(sql: "DROP TABLE subject_lineage; DROP TABLE semester_school; DELETE FROM grdb_migrations WHERE identifier='v2-school-system'")
        }
        let upgraded = try StudyStore(path: path)
        let terms = try await upgraded.semesters(userID: scope.userID)
        XCTAssertEqual(terms[0].id,scope.semesterID)
        XCTAssertEqual(terms[0].schoolTerm,SchoolTerm(stage: .high,year: 1,half: 1))
        let rows = try await upgraded.exams(scope: scope,filter: ExamFilter())
        XCTAssertEqual(rows.rows.first?.id,exams.first?.id)
        let archived = try await upgraded.snapshot()
        XCTAssertNotNil(archived.subjects.first?.lineageID)
    }
    #endif
    func testCustomColorAndAppearanceRoundTrip() throws {
        XCTAssertEqual(RGBColor.parse("#aB12fF")?.hex,"#AB12FF")
        XCTAssertNil(RGBColor.parse("#12GH00"))
        XCTAssertTrue(RGBColor.parse("#FFFFFF")!.usesDarkText)
        XCTAssertFalse(RGBColor.parse("#000000")!.usesDarkText)
        var p = Preferences(); p.accent = "#FFFF00"; p.displayMode = "dark"; p.glassVariant = "clear"; p.glassTint = 0.3
        let decoded = try JSONDecoder().decode(Preferences.self,from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.displayMode,"dark"); XCTAssertEqual(decoded.glassVariant,"clear"); XCTAssertEqual(decoded.accent,"#FFFF00")
    }
    func testDuplicateTermRollsBackAndWidgetsRespectMultiUser() async throws {
        let store = try StudyStore(path: ":memory:")
        let term = SchoolTerm(stage: .high,year: 1,half: 1)
        let first = try await store.createProfile(name: "甲",term: term,avatar: nil)
        _ = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: first)
        do { _ = try await store.saveSchoolSemester(term: term,userID: first.userID); XCTFail("duplicate term") } catch StudyError.duplicate {}
        let semesters = try await store.semesters(userID: first.userID); XCTAssertEqual(semesters.count,1)
        var p = try await store.preferences(); p.multiUserEnabled = true; try await store.updatePreferences(p)
        let second = try await store.createProfile(name: "乙",term: term,avatar: nil)
        _ = try await store.saveSubject(id: nil,name: "物理",fullScore: 7000,scope: second)
        p = try await store.preferences(); p.multiUserEnabled = false; try await store.updatePreferences(p)
        let snapshot = try await store.snapshot()
        let archive = WidgetArchive.make(snapshot)
        XCTAssertTrue(archive.series.allSatisfy { $0.userID == second.userID })
        XCTAssertTrue(archive.series.allSatisfy { $0.deepLink?.scheme == "studytrack" })
        do { try await store.select(first); XCTFail("switch must fail") } catch StudyError.invalid {}
        let restored = try BackupCodec.decode(BackupCodec.encode(snapshot,resources: [:]))
        XCTAssertEqual(restored.snapshot.subjects.count,2)
    }
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
