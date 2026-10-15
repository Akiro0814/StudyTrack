import SwiftUI
import StudyTrackCore

struct SummaryView: View {
    let summary: ExamSummary
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top,spacing: 12) { values }
            VStack(alignment: .leading,spacing: 16) { values }
        }.padding(.vertical,4)
        Text("平均分、最高分按原始分计算，不同满分的科目仅供参考。")
            .font(.caption).foregroundStyle(.secondary)
    }
    @ViewBuilder var values: some View {
        metric("平均分",summary.average.map { String(format: "%.1f",$0) } ?? "—")
        metric("最高分",summary.maximum.map(Score.text) ?? "—")
        metric("优秀率",summary.excellenceRate.map { "\($0)%" } ?? "—")
    }
    func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading,spacing: 8) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.system(.title2,design: .rounded,weight: .bold)).monospacedDigit().contentTransition(.numericText()).fixedSize(horizontal: true,vertical: false) }
            .frame(maxWidth: .infinity,alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}
struct ExamRowView: View {
    let exam: Exam; let subjects: [Subject]
    var body: some View {
        let subject = subjects.first { $0.id == exam.subjectID }
        HStack(alignment: .center,spacing: 14) {
            Image(systemName: "doc.text").font(.title3).foregroundStyle(.tint)
                .frame(width: 42,height: 48).background(.tint.opacity(0.08),in: RoundedRectangle(cornerRadius: 13)).accessibilityHidden(true)
            VStack(alignment: .leading,spacing: 6) {
                Text(exam.name.isEmpty ? exam.type.label : exam.name).font(.headline)
                Text(subject?.name ?? "科目").font(.subheadline).foregroundStyle(.secondary)
                Text(exam.date.description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing,spacing: 6) {
                Text(Score.text(exam.score)).font(.system(.title2,design: .rounded,weight: .semibold)).monospacedDigit()
                Text("/ \(subject.map { Score.text($0.fullScore) } ?? "—") · \(Grade.classify(score: exam.score,full: subject?.fullScore ?? 0).rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical,4).accessibilityElement(children: .combine)
    }
}
struct AddExamButton: View {
    let action: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        if model.preferences.theme == "glass" && !reduceTransparency {
            Button("添加成绩",systemImage: "plus",action: action).padding(12).glassEffect(.regular.interactive(),in: .capsule)
        } else { Button("添加成绩",systemImage: "plus",action: action).buttonStyle(StudyPrimaryButtonStyle()).controlSize(.large) }
    }
}
struct InlineError: View {
    let message: String?
    var body: some View { if let message { Label(message,systemImage: "exclamationmark.circle").foregroundStyle(.red).font(.callout).accessibilityLabel("错误：\(message)") } }
}
