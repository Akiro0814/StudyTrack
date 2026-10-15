import XCTest
@testable import StudyTrackCore

final class RepositoryTests: XCTestCase {
    func testDuplicateNamesReturnActionableDomainError() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "甲",semester: "秋季")
        _ = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        do { _ = try await store.saveSubject(id: nil,name: " 数学 ",fullScore: 10000,scope: scope); XCTFail("重名应失败") }
        catch StudyError.duplicate {} catch { XCTFail("应返回可解释的重复错误：\(error)") }
        do { _ = try await store.saveSemester(name: " 秋季 ",userID: scope.userID); XCTFail("重名应失败") }
        catch StudyError.duplicate {} catch { XCTFail("应返回可解释的重复错误：\(error)") }
    }
    func testScopeIsolationAndAtomicBatchRollback() async throws {
        let store = try StudyStore(path: ":memory:")
        let first = try await store.createUser(name: "甲", semester: "秋季")
        var multi = try await store.preferences(); multi.multiUserEnabled = true; try await store.updatePreferences(multi)
        let second = try await store.createUser(name: "乙", semester: "秋季")
        let subject = try await store.saveSubject(id: nil, name: "数学", fullScore: 10000, scope: first)
        let date = try LocalDate("2026-10-12")
        let input = ExamInput(subjectID: subject.id, name: "月考", date: date, score: 8950)
        do { _ = try await store.saveExams([input], scope: second); XCTFail("跨用户写入应失败") } catch {}
        do { _ = try await store.saveExams([input, input], scope: first); XCTFail("整批重复应失败") } catch {}
        let empty = try await store.exams(scope: first, filter: ExamFilter(), offset: 0, limit: 50)
        XCTAssertEqual(empty.total, 0)
        _ = try await store.saveExams([input], scope: first)
        do {
            _ = try await store.saveSubject(id: subject.id, name: "数学", fullScore: 8000, scope: first)
            XCTFail("低于历史最高分应失败")
        } catch {}
        let other = try await store.exams(scope: second, filter: ExamFilter(), offset: 0, limit: 50)
        XCTAssertEqual(other.total, 0)
    }

    func testSummaryUsesAllFilteredRowsAndLiteralSearch() async throws {
        let store = try StudyStore(path: ":memory:")
        let scope = try await store.createUser(name: "甲", semester: "秋季")
        let subject = try await store.saveSubject(id: nil, name: "数学", fullScore: 10000, scope: scope)
        for i in 0..<60 {
            _ = try await store.saveExams([ExamInput(subjectID: subject.id, name: "考试\(i)%", date: try LocalDate("2026-10-12"), score: Int64(i * 100))], scope: scope)
        }
        let page = try await store.exams(scope: scope, filter: ExamFilter(search: "%"), offset: 0, limit: 50)
        XCTAssertEqual(page.rows.count, 50)
        XCTAssertEqual(page.total, 60)
        XCTAssertEqual(page.summary.average, 29.5)
        let none = try await store.exams(scope: scope, filter: ExamFilter(search: "_"), offset: 0, limit: 50)
        XCTAssertEqual(none.total, 0)
    }
}
