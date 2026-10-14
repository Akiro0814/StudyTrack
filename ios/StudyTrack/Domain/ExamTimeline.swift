import Foundation

/// Each examination gets a distinct ordinal, including examinations on the same day.
/// Missing ranks keep their original positions. Sampling never changes the x coordinate.
public enum ExamTimeline {
    public enum Metric: Sendable { case score, classRank, gradeRank, districtRank }
    public struct Point: Identifiable, Sendable {
        public var id: String { exam.id }
        public let position: Int
        public let exam: Exam
        public let value: Double
    }
    public static func points(_ exams: [Exam], metric: Metric, maximumPoints: Int = 500) -> [Point] {
        let ordered = exams.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
        let points = ordered.enumerated().compactMap { index, exam -> Point? in
            let value: Double?
            switch metric {
            case .score: value = Double(exam.score)/100
            case .classRank: value = exam.classRank.map(Double.init)
            case .gradeRank: value = exam.gradeRank.map(Double.init)
            case .districtRank: value = exam.districtRank.map(Double.init)
            }
            guard let value else { return nil }
            return Point(position: index+1,exam: exam,value: value)
        }
        return TrendSampler.indices(values: points.map { Int64(($0.value*100).rounded()) },maximumPoints: maximumPoints).map { points[$0] }
    }
}
