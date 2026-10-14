import XCTest
@testable import StudyTrackCore

final class PersistenceTests: XCTestCase {
    func testColdReopenAndTenThousandRowImport() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("study.sqlite").path
        let store = try StudyStore(path: path)
        let scope = try await store.createUser(name: "合成学生",semester: "性能夹具")
        let date = try LocalDate("2026-10-12")
        let rows = (0..<10000).map { i in
            ExchangeRow(row: i+2,semester: "",subject: "数学",name: "考试\(i)",date: date,score: Int64(i%10001),fullScore: 10000,type: .other,classRank: nil,gradeRank: i+1,districtRank: nil,reflection: nil)
        }
        let start = Date()
        let plan = try await store.previewImport(ParsedWorkbook(rows: rows,issues: []),scope: scope,fileDigest: "synthetic-10000")
        let report = try await store.commitImport(plan,validRowsOnly: false,acceptConversions: false)
        XCTAssertEqual(report.imported,10000)
        let reopened = try StudyStore(path: path)
        let page = try await reopened.exams(scope: scope,filter: ExamFilter(),offset: 9950,limit: 50)
        XCTAssertEqual(page.total,10000); XCTAssertEqual(page.rows.count,50)
        XCTAssertEqual(page.summary.average,50.0); XCTAssertEqual(page.summary.minimum,0); XCTAssertEqual(page.summary.maximum,9999)
        let snapshot = try await reopened.snapshot()
        let data = try BackupCodec.encode(snapshot,resources: [:])
        let verified = try BackupCodec.decode(data)
        XCTAssertEqual(verified.snapshot.exams.count,10000)
        print("Synthetic 10000-row preview + import + reopen + backup verification: \(Date().timeIntervalSince(start)) seconds; host measurement only")
    }

    func testDecimalAverageRoundsHalfUp() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "甲",semester: "秋季")
        let subject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        _ = try await store.saveExams([ExamInput(subjectID: subject.id,name: "边界",date: try LocalDate("2026-10-12"),score: 15)],scope: scope)
        let page = try await store.exams(scope: scope,filter: ExamFilter(),offset: 0,limit: 50)
        XCTAssertEqual(page.summary.average,0.2)
    }
}
