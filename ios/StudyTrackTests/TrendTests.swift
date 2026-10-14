import XCTest
@testable import StudyTrackCore

final class TrendTests: XCTestCase {
    func testSamplingRetainsExtremaAndEndpoints() {
        let values: [Int64] = (0..<10000).map { $0 == 1234 ? 10000 : $0 == 4567 ? 0 : 5000 }
        let indices = TrendSampler.indices(values: values,maximumPoints: 500)
        XCTAssertLessThanOrEqual(indices.count,500)
        XCTAssertEqual(indices.first,0); XCTAssertEqual(indices.last,9999)
        XCTAssertTrue(indices.contains(1234)); XCTAssertTrue(indices.contains(4567))
        XCTAssertEqual(indices,indices.sorted())
    }
    func testShortSeriesIsNotInventedOrDuplicated() {
        XCTAssertEqual(TrendSampler.indices(values: [85],maximumPoints: 500),[0])
        XCTAssertEqual(TrendSampler.indices(values: [],maximumPoints: 500),[])
    }
}
