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
    public struct AxisTick: Identifiable, Sendable {
        public let position: Double
        public let label: String
        public var id: Double { position }
    }
    public var domain: ClosedRange<Double> {
        let low = all.map(\.x).min() ?? 0
        let high = all.map(\.x).max() ?? low
        let padding = max(0.04,(high-low)*0.08)
        return (low-padding)...(high+padding)
    }
    public var axisTicks: [AxisTick] {
        let ordered = all.sorted { $0.x < $1.x }
        guard !ordered.isEmpty else { return [] }
        let singleDay = Set(ordered.map { $0.exam.date }).count == 1
        var candidates: [AxisTick] = []
        var seen = Set<LocalDate>()
        for (index,point) in ordered.enumerated() {
            if singleDay { candidates.append(AxisTick(position: point.x,label: "\(index+1)")) }
            else if seen.insert(point.exam.date).inserted { candidates.append(AxisTick(position: point.x,label: String(point.exam.date.description.suffix(5)))) }
        }
        guard candidates.count > 4 else { return candidates }
        return (0..<4).map { candidates[$0*(candidates.count-1)/3] }
    }
    public var axisCaption: String {
        if let first = all.first, Set(all.map { $0.exam.date }).count == 1 { return "\(first.exam.date.description) · 横轴为同日考试次序" }
        return "按真实日期排列 · 同日考试独立显示"
    }
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
