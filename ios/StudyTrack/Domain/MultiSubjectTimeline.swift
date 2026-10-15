import Foundation

public struct MultiSubjectTimeline: Sendable {
    public struct Point: Identifiable, Sendable {
        public var id: String { exam.id }
        public let groupID: String
        public let exam: Exam
        public let x: Double
        public var value: Double { Double(exam.score)/100 }
    }
    public let all: [Point]
    public let plotted: [Point]
    public init(groups: [AnalysisGroup],maximumPointsPerSubject: Int = 200) {
        let exams = groups.flatMap(\.exams).sorted { ($0.date.description,$0.createdAt,$0.id) < ($1.date.description,$1.createdAt,$1.id) }
        let days = Dictionary(grouping: exams,by: \.date)
        var positions: [String: Double] = [:]
        for (_,rows) in days {
            for (index,exam) in rows.enumerated() {
                positions[exam.id] = exam.date.date.timeIntervalSince1970/86400 + Double(index)/Double(max(1,rows.count))*0.4
            }
        }
        var all: [Point] = [], plotted: [Point] = []
        for group in groups {
            let sorted = group.exams.sorted { ($0.date.description,$0.createdAt,$0.id) < ($1.date.description,$1.createdAt,$1.id) }
            let points = sorted.map { Point(groupID: group.id,exam: $0,x: positions[$0.id]!) }
            all.append(contentsOf: points)
            let indices = TrendSampler.indices(values: sorted.map(\.score),maximumPoints: maximumPointsPerSubject)
            plotted.append(contentsOf: indices.map { points[$0] })
        }
        self.all = all; self.plotted = plotted
    }
}
