import XCTest
@testable import StudyTrackCore

final class ExchangeTests: XCTestCase {
    func testMergedExtraCellsInRowTwentyOneAreNotMisreadAsHeaderMerges() throws {
        let row = ExchangeRow(row: 2,semester: "秋季",subject: "数学",name: "月考",date: try LocalDate("2026-10-12"),score: 8500,fullScore: 10000,type: .monthly,classRank: nil,gradeRank: nil,districtRank: nil,reflection: nil)
        var files = try SafeArchive.read(XLSXCodec.encode([row]),compressedLimit: 20*1024*1024,expandedLimit: 200*1024*1024)
        let path = "xl/worksheets/sheet1.xml"
        let original = String(decoding: files[path]!,as: UTF8.self)
        files[path] = Data(original.replacingOccurrences(of: "</worksheet>",with: "<mergeCells><mergeCell ref=\"L21:M21\"/></mergeCells></worksheet>").utf8)
        XCTAssertEqual(try XLSXCodec.decode(SafeArchive.write(files)).rows.count,1)
        files[path] = Data(original.replacingOccurrences(of: "</worksheet>",with: "<mergeCells><mergeCell ref=\"A1:B1\"/></mergeCells></worksheet>").utf8)
        XCTAssertThrowsError(try XLSXCodec.decode(SafeArchive.write(files)))
    }
    func testXLSXRoundTripPreservesSparseRanksAndLiteralFormulaText() throws {
        let row = ExchangeRow(row: 2, semester: "秋季", subject: "数学", name: "=不是公式", date: try LocalDate("2026-10-12"), score: 8950, fullScore: 10000, type: .monthly, classRank: nil, gradeRank: 1, districtRank: nil, reflection: "中文\n第二行")
        let data = try XLSXCodec.encode([row])
        let result = try XLSXCodec.decode(data)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.rows.first?.name, "=不是公式")
        XCTAssertEqual(result.rows.first?.gradeRank, 1)
        XCTAssertNil(result.rows.first?.classRank)
        XCTAssertEqual(result.rows.first?.reflection, "中文\n第二行")
    }

    func testBackupRestoreAndCorruptionKeepOldData() async throws {
        let store = try StudyStore(path: ":memory:")
        _ = try await store.createUser(name: "甲", semester: "秋季")
        let snapshot = try await store.snapshot()
        let data = try BackupCodec.encode(snapshot, resources: [:])
        let verified = try BackupCodec.decode(data)
        XCTAssertEqual(verified.snapshot.users.count, 1)
        _ = try await store.createUser(name: "乙", semester: "春季")
        try await store.restore(verified.snapshot)
        let restored = try await store.snapshot()
        XCTAssertEqual(restored.users.count, 1)
        XCTAssertEqual(restored.datasetID, snapshot.datasetID)
        XCTAssertThrowsError(try BackupCodec.decode(Data("坏文件".utf8)))
    }

    func testRejectUnsafeArchivePaths() {
        for path in ["../data.json", "/data.json", "assets/../../data", "C:/x", "assets\\x", "assets//x"] {
            XCTAssertThrowsError(try SafeArchive.validatePath(path))
        }
    }
}
