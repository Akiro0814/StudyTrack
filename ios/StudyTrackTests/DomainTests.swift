import XCTest
@testable import StudyTrackCore

final class DomainTests: XCTestCase {
    func testScorePrecisionAndBoundaries() throws {
        XCTAssertEqual(try Score.parse("89.5"), 8950)
        XCTAssertEqual(try Score.parse("89.50"), 8950)
        for invalid in ["NaN", "Infinity", "1.001", "-1", "1e2", ""] {
            XCTAssertThrowsError(try Score.parse(invalid))
        }
        XCTAssertEqual([8500, 8499, 7500, 7499, 6000, 5999].map {
            Grade.classify(score: Int64($0), full: 10000)
        }, [.a, .b, .b, .c, .c, .d])
        XCTAssertEqual(Grade.classify(score: 12750, full: 15000), .a)
    }

    func testCalendarDatesAreStrictAndTimezoneIndependent() throws {
        XCTAssertEqual(try LocalDate("2024-02-29").description, "2024-02-29")
        for invalid in ["2025-02-29", "2026-1-01", "2026-13-01", "0000-01-01"] {
            XCTAssertThrowsError(try LocalDate(invalid))
        }
        XCTAssertEqual(try LocalDate.excel(serial: 1, system1904: false).description, "1900-01-01")
        XCTAssertEqual(try LocalDate.excel(serial: 61, system1904: false).description, "1900-03-01")
        XCTAssertThrowsError(try LocalDate.excel(serial: 60, system1904: false))
        XCTAssertEqual(try LocalDate.excel(serial: 0, system1904: true).description, "1904-01-01")
    }

    func testNormalizationPreservesMeaningfulDifferences() {
        XCTAssertEqual(normalize("  e\u{301}\n"), "é")
        XCTAssertNotEqual(normalize("Math"), normalize("math"))
        XCTAssertNotEqual(normalize("数 学"), normalize("数学"))
    }
}
