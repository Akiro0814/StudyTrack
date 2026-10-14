import Foundation

public enum StudyError: Error, LocalizedError, Sendable {
    case invalid(String), duplicate, scopeChanged, notFound, unsupported(String), corrupt(String)
    public var errorDescription: String? {
        switch self {
        case .invalid(let message), .unsupported(let message), .corrupt(let message): message
        case .duplicate: "存在相同名称或重复成绩，请检查后重试。"
        case .scopeChanged: "数据或当前用户/学期已变化，请重新预览。"
        case .notFound: "记录不存在，或不属于当前用户与学期。"
        }
    }
}

public func normalize(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
}

public struct StudyScope: Codable, Hashable, Sendable {
    public let userID: String
    public let semesterID: String
    public init(userID: String, semesterID: String) { self.userID = userID; self.semesterID = semesterID }
}

public struct LocalDate: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let description: String
    public init(_ text: String) throws {
        guard text.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil else {
            throw StudyError.invalid("日期必须为 YYYY-MM-DD。")
        }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard parts[0] >= 1, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.component(.year, from: date) == parts[0], calendar.component(.month, from: date) == parts[1],
              calendar.component(.day, from: date) == parts[2] else { throw StudyError.invalid("日期不存在：\(text)") }
        description = text
    }
    public init(from decoder: any Decoder) throws { try self.init(decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(description) }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.description < rhs.description }
    public var date: Date {
        let parts = description.split(separator: "-").compactMap { Int($0) }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }
    public init(date: Date, timeZone: TimeZone = .current) {
        var c = Calendar(identifier: .gregorian); c.timeZone = timeZone
        description = String(format: "%04d-%02d-%02d", c.component(.year, from: date), c.component(.month, from: date), c.component(.day, from: date))
    }
    public static func excel(serial: Double, system1904: Bool) throws -> Self {
        guard serial.isFinite, serial >= (system1904 ? 0 : 1), serial < 2_958_466,
              system1904 || Int(serial) != 60 else { throw StudyError.invalid("Excel 日期序列无效。") }
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = c.date(from: DateComponents(year: system1904 ? 1904 : 1899, month: system1904 ? 1 : 12, day: system1904 ? 1 : 31))!
        let days = Int(serial) - (!system1904 && serial >= 61 ? 1 : 0)
        guard let result = c.date(byAdding: .day, value: days, to: base) else { throw StudyError.invalid("Excel 日期越界。") }
        return Self(date: result, timeZone: c.timeZone)
    }
}

public enum Score {
    // Upper bound also ensures safe grade cross multiplication and exact XLSX numeric representation.
    public static let maximum: Int64 = 1_000_000_000
    public static func parse(_ text: String, decimalSeparator: String = ".") throws -> Int64 {
        let value = normalize(text).replacingOccurrences(of: decimalSeparator, with: ".")
        guard value.range(of: #"^[0-9]+(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else {
            throw StudyError.invalid("分数须为非负数，最多两位小数。")
        }
        let parts = value.split(separator: ".")
        guard let whole = Int64(parts[0]), whole <= maximum / 100 else { throw StudyError.invalid("分数超出支持范围。") }
        let fraction = parts.count == 2 ? Int64(String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0))! : 0
        let result = whole * 100 + fraction
        guard result <= maximum else { throw StudyError.invalid("分数超出支持范围。") }
        return result
    }
    public static func text(_ minor: Int64) -> String {
        let base = "\(minor / 100)"
        return minor % 100 == 0 ? base : base + "." + (minor % 10 == 0 ? "\(minor % 100 / 10)" : String(format: "%02d", minor % 100))
    }
    public static func fixed(_ minor: Int64) -> String { String(format: "%lld.%02lld", minor / 100, minor % 100) }
    public static func rank(_ text: String) throws -> Int? {
        if normalize(text).isEmpty { return nil }
        guard text.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              let n = Int(text), n > 0 else { throw StudyError.invalid("排名必须为空或正整数。") }
        return n
    }
}

public enum Grade: String, Codable, Sendable { case a = "A", b = "B", c = "C", d = "D"
    public static func classify(score: Int64, full: Int64) -> Self {
        guard score >= 0, full > 0, score <= Score.maximum, full <= Score.maximum else { return .d }
        return score * 100 >= full * 85 ? .a : score * 100 >= full * 75 ? .b : score * 100 >= full * 60 ? .c : .d
    }
}

public enum ExamType: String, Codable, CaseIterable, Sendable {
    case monthly, midterm, final, other
    public var label: String { switch self { case .monthly: "月考"; case .midterm: "期中"; case .final: "期末"; case .other: "其他" } }
    public static func fromLabel(_ label: String) -> Self? { allCases.first { $0.label == label || $0.rawValue == label } }
}

public struct User: Identifiable, Codable, Hashable, Sendable {
    public var id: String; public var name: String; public var createdAt: String; public var updatedAt: String
}
public struct Semester: Identifiable, Codable, Hashable, Sendable {
    public var id: String; public var userID: String; public var name: String; public var createdAt: String; public var updatedAt: String
}
public struct Subject: Identifiable, Codable, Hashable, Sendable {
    public var id: String; public var userID: String; public var semesterID: String; public var name: String
    public var fullScore: Int64; public var createdAt: String; public var updatedAt: String
}
public struct Exam: Identifiable, Codable, Hashable, Sendable {
    public var id: String; public var userID: String; public var semesterID: String; public var subjectID: String
    public var name: String; public var date: LocalDate; public var score: Int64; public var type: ExamType
    public var classRank: Int?; public var gradeRank: Int?; public var districtRank: Int?; public var reflection: String?
    public var attachmentID: String?; public var createdAt: String; public var updatedAt: String
}
public struct ExamInput: Codable, Sendable {
    public var id: String?; public var subjectID: String; public var name: String; public var date: LocalDate
    public var score: Int64; public var type: ExamType; public var classRank: Int?; public var gradeRank: Int?
    public var districtRank: Int?; public var reflection: String?
    public init(id: String? = nil, subjectID: String, name: String, date: LocalDate, score: Int64, type: ExamType = .monthly,
                classRank: Int? = nil, gradeRank: Int? = nil, districtRank: Int? = nil, reflection: String? = nil) {
        self.id = id; self.subjectID = subjectID; self.name = name; self.date = date; self.score = score; self.type = type
        self.classRank = classRank; self.gradeRank = gradeRank; self.districtRank = districtRank; self.reflection = reflection
    }
}
public struct ExamFilter: Sendable {
    public var subjectID: String?; public var search: String
    public init(subjectID: String? = nil, search: String = "") { self.subjectID = subjectID; self.search = search }
}
public struct ExamSummary: Sendable {
    public var count: Int = 0; public var average: Double?; public var minimum: Int64?; public var maximum: Int64?; public var excellenceRate: Int?
    public init(count: Int = 0, average: Double? = nil, minimum: Int64? = nil, maximum: Int64? = nil, excellenceRate: Int? = nil) {
        self.count = count; self.average = average; self.minimum = minimum; self.maximum = maximum; self.excellenceRate = excellenceRate
    }
}
public struct ExamPage: Sendable {
    public var rows: [Exam]; public var total: Int; public var summary: ExamSummary
    public init(rows: [Exam], total: Int, summary: ExamSummary) { self.rows = rows; self.total = total; self.summary = summary }
}

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Decimal), bool(Bool), null
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Decimal.self) { self = .number(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .object(let v): try c.encode(v); case .array(let v): try c.encode(v); case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v); case .bool(let v): try c.encode(v); case .null: try c.encodeNil() }
    }
}
public struct Preferences: Codable, Sendable {
    public var theme = "simple"; public var accent = "blue"; public var wallpaperAssetID: String?
    public var multiUserEnabled = false; public var currentUserID: String?; public var currentSemesterID: String?
    public var nameNormalizationVersion = 1; public var platformExtensions: [String: JSONValue] = [:]
    public init() {}
    public var scope: StudyScope? {
        guard let u = currentUserID, let s = currentSemesterID else { return nil }; return StudyScope(userID: u, semesterID: s)
    }
}
public struct Asset: Codable, Sendable {
    public var id: String; public var relativePath: String; public var mimeType: String; public var sha256: String; public var byteCount: Int
    public init(id: String, relativePath: String, mimeType: String, sha256: String, byteCount: Int) {
        self.id = id; self.relativePath = relativePath; self.mimeType = mimeType; self.sha256 = sha256; self.byteCount = byteCount
    }
}
public struct LegacyID: Codable, Sendable {
    public var sourceDatasetID: String; public var entityType: String; public var legacyID: String; public var canonicalID: String
}
public struct Snapshot: Codable, Sendable {
    public var datasetID: String; public var users: [User]; public var semesters: [Semester]; public var subjects: [Subject]
    public var exams: [Exam]; public var assets: [Asset]; public var legacyIDMap: [LegacyID]; public var preferences: Preferences
}
public protocol ExamRepository: Sendable {
    func exams(scope: StudyScope, filter: ExamFilter, offset: Int, limit: Int) async throws -> ExamPage
    func saveExams(_ inputs: [ExamInput], scope: StudyScope) async throws -> [Exam]
    func deleteExam(id: String, scope: StudyScope) async throws
}
