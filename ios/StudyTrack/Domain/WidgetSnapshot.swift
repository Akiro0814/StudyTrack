import Foundation

public struct WidgetSeries: Identifiable, Codable, Sendable {
    public var id: String
    public var userID: String
    public var semesterID: String
    public var subjectID: String
    public var wholeStage: Bool
    public var title: String
    public var subtitle: String
    public var fullScore: Int64
    public var scores: [Int64]
    public var dates: [String]
    public var average: Double?
    public var maximum: Int64?
    public var excellenceRate: Int?
    public var count: Int
    public var deepLink: URL? {
        var components = URLComponents(); components.scheme = "studytrack"; components.host = "analysis"
        components.queryItems = [URLQueryItem(name: "user",value: userID),URLQueryItem(name: "semester",value: semesterID),URLQueryItem(name: "subject",value: subjectID),URLQueryItem(name: "stage",value: wholeStage ? "1" : "0")]
        return components.url
    }
}
public struct WidgetArchive: Codable, Sendable {
    public var updatedAt: Date
    public var defaultID: String?
    public var series: [WidgetSeries]
    public static let appGroup = "group.com.repea.studytrack.ios"
    public static let filename = "widget-snapshot.json"
    public static func make(_ snapshot: Snapshot) -> Self {
        let users = snapshot.users.filter { snapshot.preferences.multiUserEnabled || $0.id == snapshot.preferences.currentUserID }
        var series: [WidgetSeries] = []
        for user in users {
            let semesters = snapshot.semesters.filter { $0.userID == user.id }
            for term in semesters {
                let scopes: [Bool] = term.schoolTerm == nil ? [false] : [false,true]
                for wholeStage in scopes {
                    let ids = Set(semesters.filter { wholeStage ? $0.schoolTerm?.stage == term.schoolTerm?.stage : $0.id == term.id }.map(\.id))
                    let subjects = snapshot.subjects.filter { $0.userID == user.id && ids.contains($0.semesterID) }
                    let groups = Dictionary(grouping: subjects) { "\($0.lineageID ?? $0.id)|\($0.fullScore)" }
                    for (key,values) in groups {
                        let subjectIDs = Set(values.map(\.id)), representative = values.first { $0.semesterID == term.id } ?? values[0]
                        let rows = snapshot.exams.filter { $0.userID == user.id && subjectIDs.contains($0.subjectID) }.sorted { ($0.date.description,$0.createdAt,$0.id) < ($1.date.description,$1.createdAt,$1.id) }
                        let summary = AnalysisGroup.summarize(rows,full: representative.fullScore)
                        series.append(WidgetSeries(id: "\(user.id)|\(term.id)|\(wholeStage)|\(key)",userID: user.id,semesterID: term.id,subjectID: representative.id,wholeStage: wholeStage,title: representative.name,subtitle: user.name + " · " + (wholeStage ? (term.schoolTerm?.stage.label ?? term.name) : term.name),fullScore: representative.fullScore,scores: rows.suffix(120).map(\.score),dates: rows.suffix(120).map { $0.date.description },average: summary.average,maximum: summary.maximum,excellenceRate: summary.excellenceRate,count: rows.count))
                    }
                }
            }
        }
        series.sort { $0.subtitle == $1.subtitle ? $0.title < $1.title : $0.subtitle < $1.subtitle }
        let current = series.first { $0.userID == snapshot.preferences.currentUserID && $0.semesterID == snapshot.preferences.currentSemesterID && !$0.wholeStage }
        return Self(updatedAt: Date(),defaultID: current?.id,series: series)
    }
    #if os(iOS) || os(macOS)
    public static var fileURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent(filename) }
    public static func load() -> Self? {
        guard let fileURL,let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Self.self,from: data)
    }
    #endif
}
