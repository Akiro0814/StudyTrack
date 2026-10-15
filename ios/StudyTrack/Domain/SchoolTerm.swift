import Foundation

public enum SchoolStage: String, Codable, CaseIterable, Sendable, Identifiable {
    case primary, junior, high, university
    public var id: String { rawValue }
    public var label: String { switch self { case .primary: "小学阶段"; case .junior: "初中阶段"; case .high: "高中阶段"; case .university: "大学阶段" } }
    public var years: Int { switch self { case .primary: 6; case .junior, .high: 3; case .university: 4 } }
}
public struct SchoolTerm: Codable, Hashable, Sendable, Identifiable {
    public let stage: SchoolStage
    public let year: Int
    public let half: Int
    public init(stage: SchoolStage, year: Int, half: Int) { self.stage = stage; self.year = year; self.half = half }
    public var id: String { "\(stage.rawValue)-\(year)-\(half)" }
    public var order: Int { year * 2 + half }
    public var valid: Bool { (1...stage.years).contains(year) && (1...2).contains(half) }
    public var label: String {
        let numbers = ["一", "二", "三", "四", "五", "六"]
        guard valid else { return "无效学期" }
        let prefix = switch stage { case .primary: "\(numbers[year-1])年级"; case .junior: "初\(numbers[year-1])"; case .high: "高\(numbers[year-1])"; case .university: "大\(numbers[year-1])" }
        return prefix + (half == 1 ? "上学期" : "下学期")
    }
    public static func catalog(for stage: SchoolStage) -> [Self] {
        (1...stage.years).flatMap { year in (1...2).map { Self(stage: stage, year: year, half: $0) } }
    }
    public static func recognize(_ name: String) -> Self? {
        let cleaned = normalize(name).replacingOccurrences(of: " · ", with: "").replacingOccurrences(of: " ", with: "")
        return SchoolStage.allCases.flatMap { catalog(for: $0) }.first {
            cleaned == $0.label || cleaned == $0.stage.label + "-" + $0.label ||
            ($0.stage == .primary && cleaned == "\($0.year)年级" + ($0.half == 1 ? "上学期" : "下学期"))
        }
    }
}

public struct AnalysisGroup: Identifiable, Sendable {
    public var id: String
    public var subject: Subject
    public var exams: [Exam]
    public var summary: ExamSummary { Self.summarize(exams, full: subject.fullScore) }
    public static func summarize(_ exams: [Exam], full: Int64) -> ExamSummary {
        guard !exams.isEmpty else { return ExamSummary() }
        let total = exams.reduce(Int64(0)) { $0 + $1.score }
        return ExamSummary(count: exams.count, average: (Double(total) / Double(exams.count) / 10).rounded() / 10,
                           minimum: exams.map(\.score).min(), maximum: exams.map(\.score).max(),
                           excellenceRate: exams.filter { Grade.classify(score: $0.score, full: full) == .a }.count * 100 / exams.count)
    }
}
public struct AnalysisData: Sendable {
    public var subjects: [Subject]
    public var exams: [Exam]
    public var groups: [AnalysisGroup]
    public init(subjects: [Subject] = [], exams: [Exam] = [], groups: [AnalysisGroup] = []) { self.subjects = subjects; self.exams = exams; self.groups = groups }
}
