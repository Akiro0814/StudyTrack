import XCTest
@testable import StudyTrackCore

final class FixtureTests: XCTestCase {
    func fixture(_ filename: String) throws -> Data {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let url = bundle.url(forResource: filename,withExtension: nil,subdirectory: "Fixtures") ?? bundle.url(forResource: filename,withExtension: nil)
        return try Data(contentsOf: XCTUnwrap(url))
    }
    func testIndependentXLSXAndEdgeCases() throws {
        let result = try XLSXCodec.decode(fixture("independent.xlsx"))
        XCTAssertEqual(result.rows.count,1); XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.rows[0].name,"=文字"); XCTAssertNil(result.rows[0].classRank)
        XCTAssertEqual(result.rows[0].gradeRank,1); XCTAssertEqual(result.rows[0].reflection,"中文\n第二行")
        let edge = try XLSXCodec.decode(fixture("edge-cases.xlsx"))
        XCTAssertEqual(edge.rows.count,2)
        XCTAssertEqual(edge.rows[0].date.description,"1900-03-01")
        XCTAssertEqual(Set(edge.issues.filter { !$0.warning }.map(\.row)),Set([3,4,5,6]))
        XCTAssertEqual(edge.issues.filter(\.warning).count,2)
        let date = try XLSXCodec.decode(fixture("date1904.xlsx"))
        XCTAssertEqual(date.rows[0].date.description,"1904-01-01")
        let poi = try XLSXCodec.decode(fixture("android-poi.xlsx"))
        XCTAssertEqual(poi.rows.count,1); XCTAssertEqual(poi.rows[0].score,8950)
        XCTAssertEqual(poi.rows[0].name,"=文字"); XCTAssertEqual(poi.rows[0].gradeRank,1)
        XCTAssertThrowsError(try XLSXCodec.decode(fixture("duplicate-headers.xlsx")))
        if let directory = ProcessInfo.processInfo.environment["STUDYTRACK_ARTIFACTS"] {
            try XLSXCodec.encode(result.rows).write(to: URL(fileURLWithPath: directory).appendingPathComponent("ios-export.xlsx"))
        }
    }
    func testGoldenBackupAndIndependentStatistics() async throws {
        let golden = try BackupCodec.decode(fixture("golden.studytrackbackup"))
        let store = try StudyStore(path: ":memory:"); try await store.restore(golden.snapshot)
        let snapshot = try await store.snapshot()
        XCTAssertEqual(snapshot.users.count,2); XCTAssertEqual(snapshot.semesters.count,4); XCTAssertEqual(snapshot.subjects.count,4)
        let page = try await store.exams(scope: snapshot.preferences.scope!,filter: ExamFilter(),offset: 0,limit: 50)
        XCTAssertEqual(page.summary.average,100); XCTAssertEqual(page.summary.minimum,8000); XCTAssertEqual(page.summary.maximum,12000)
        XCTAssertEqual(page.summary.excellenceRate,0)
        for name in ["unknown-version.studytrackbackup","unsafe-path.studytrackbackup","broken-reference.studytrackbackup"] {
            XCTAssertThrowsError(try BackupCodec.decode(fixture(name)))
        }
        if let directory = ProcessInfo.processInfo.environment["STUDYTRACK_ARTIFACTS"] {
            try BackupCodec.encode(snapshot,resources: [:]).write(to: URL(fileURLWithPath: directory).appendingPathComponent("ios-export.studytrackbackup"))
        }
    }
}
