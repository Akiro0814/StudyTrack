import SwiftUI
import Charts
import StudyTrackCore

struct AnalysisView: View {
    @Environment(AppModel.self) private var model
    @State private var subjectID = ""
    @State private var exams: [Exam] = []
    @State private var summary = ExamSummary()
    @State private var loading = false
    @State private var failure: String?
    @State private var rankKey = "class"
    @State private var selectedDate: Date?
    var chosenSubjects: [Subject] { model.subjects.filter { subjectID.isEmpty || $0.id == subjectID } }
    var body: some View {
        List {
            Picker("科目",selection: $subjectID) { Text("全部科目").tag(""); ForEach(model.subjects) { Text($0.name).tag($0.id) } }
            if loading { ProgressView("正在计算") }
            else if let failure { Text(failure); Button("重试") { Task { await load() } } }
            else {
                Section("所选成绩概览") { SummaryView(summary: summary) }
                if exams.isEmpty { ContentUnavailableView("暂无可分析的成绩",systemImage: "chart.xyaxis.line",description: Text("记录成绩后，这里会展示变化。")) }
                ForEach(chosenSubjects) { subject in
                    let rows = exams.filter { $0.subjectID == subject.id }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
                    if !rows.isEmpty {
                        Section("\(subject.name) · 分数趋势") {
                            Chart(sample(rows,ranked: false)) { exam in
                                LineMark(x: .value("日期",exam.date.date),y: .value("分数",Double(exam.score)/100))
                                PointMark(x: .value("日期",exam.date.date),y: .value("分数",Double(exam.score)/100))
                                    .accessibilityLabel("\(exam.date.description)，\(exam.name)，\(Score.text(exam.score)) 分")
                            }.chartYScale(domain: 0...Double(subject.fullScore)/100).chartXSelection(value: $selectedDate).frame(minHeight: 220)
                            if let selectedDate, let closest = rows.min(by: { abs($0.date.date.timeIntervalSince(selectedDate)) < abs($1.date.date.timeIntervalSince(selectedDate)) }) {
                                Text("\(closest.date.description) · \(closest.name) · \(Score.text(closest.score))/\(Score.text(subject.fullScore))").font(.callout)
                            }
                            Text("\(rows.count) 次考试，最高 \(Score.text(rows.map(\.score).max()!)) 分，最低 \(Score.text(rows.map(\.score).min()!)) 分。").font(.caption).foregroundStyle(.secondary)
                        }
                        Section("\(subject.name) · 排名趋势") {
                            Picker("排名",selection: $rankKey) { Text("班排").tag("class"); Text("年排").tag("grade"); Text("区排").tag("district") }.pickerStyle(.segmented)
                            let ranked = rows.filter { rank($0) != nil }
                            if ranked.isEmpty { Text("暂无此类排名。").foregroundStyle(.secondary) }
                            else {
                                Chart(sample(ranked,ranked: true)) { exam in
                                    LineMark(x: .value("日期",exam.date.date),y: .value("排名",rank(exam)!))
                                    PointMark(x: .value("日期",exam.date.date),y: .value("排名",rank(exam)!))
                                        .accessibilityLabel("\(exam.date.description)，\(exam.name)，第 \(rank(exam)!) 名")
                                }.chartYScale(domain: .automatic(includesZero: false,reversed: true)).frame(minHeight: 200)
                            }
                            Text("排名越小越好，位置越高；未填写排名的考试不补零。").font(.caption).foregroundStyle(.secondary)
                        }
                        Section("\(subject.name) · 数据明细") {
                            ForEach(rows.suffix(50).reversed()) { ExamRowView(exam: $0,subjects: model.subjects) }
                            if rows.count > 50 { Text("这里显示最近 50 条，全部记录可在“成绩”中分页查看。").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }.navigationTitle("分析").task(id: "\(subjectID)|\(model.home.total)|\(model.home.rows.first?.updatedAt ?? "")") { await load() }
    }
    func rank(_ exam: Exam) -> Int? { rankKey == "class" ? exam.classRank : rankKey == "grade" ? exam.gradeRank : exam.districtRank }
    func sample(_ rows: [Exam], ranked: Bool) -> [Exam] {
        TrendSampler.indices(values: rows.map { ranked ? Int64(rank($0) ?? 0) : $0.score }).map { rows[$0] }
    }
    func load() async {
        guard let store = model.store, let scope = model.scope else { return }; loading = true; failure = nil
        do {
            let filter = ExamFilter(subjectID: subjectID.isEmpty ? nil : subjectID)
            var page = try await store.exams(scope: scope,filter: filter,offset: 0,limit: 1000), all = page.rows
            while all.count < page.total {
                try Task.checkCancellation(); page = try await store.exams(scope: scope,filter: filter,offset: all.count,limit: 1000); all += page.rows
            }
            guard scope == model.scope, !Task.isCancelled else { return }; exams = all; summary = page.summary; loading = false
        } catch { if !Task.isCancelled { failure = model.friendly(error); loading = false } }
    }
}
