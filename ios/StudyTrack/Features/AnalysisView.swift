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
    @State private var recording: RecordIntent?
    @State private var editing: Exam?
    var chosenSubjects: [Subject] { model.subjects.filter { subjectID.isEmpty || $0.id == subjectID } }
    var body: some View {
        StudyScroll {
            VStack(alignment: .leading,spacing: 8) {
                Text("看见每一步变化。").font(.title2.bold())
                Text("每场考试独立呈现，同一天也不重叠。").font(.subheadline).foregroundStyle(.secondary)
            }
            SubjectFilter(selection: $subjectID)
            if loading { ProgressView("正在整理成绩").frame(maxWidth: .infinity) }
            else if let failure {
                EmptyStudyView(title: "暂时无法读取",message: failure,symbol: "arrow.clockwise",actionTitle: "重试") { Task { await load() } }
            } else if exams.isEmpty {
                EmptyStudyView(title: "你的曲线，等待起笔",message: "记录考试后，在这里回看分数和排名的变化。",symbol: "chart.xyaxis.line",actionTitle: "记录成绩") { recording = .single }
            } else {
                VStack(alignment: .leading,spacing: 14) { SectionHeading(title: "成绩概览",detail: "\(summary.count) 次考试"); SummaryView(summary: summary) }.studySurface()
                ForEach(chosenSubjects) { subject in
                    let rows = exams.filter { $0.subjectID == subject.id }
                    if !rows.isEmpty {
                        VStack(alignment: .leading,spacing: 16) {
                            SectionHeading(title: subject.name,detail: "满分 \(Score.text(subject.fullScore))")
                            ExamTrendCard(subject: subject,exams: rows)
                            DisclosureGroup("查看 \(rows.count) 条成绩明细") {
                                VStack(spacing: 18) {
                                    ForEach(ExamTimeline.points(rows,metric: .score,maximumPoints: Int.max).suffix(50).reversed()) { point in
                                        Button { editing = point.exam } label: { ExamRowView(exam: point.exam,subjects: model.subjects).foregroundStyle(.primary) }.buttonStyle(.plain)
                                    }
                                }.padding(.top,16)
                            }.font(.subheadline).studySurface()
                        }
                    }
                }
            }
        }.navigationTitle("分析").navigationBarTitleDisplayMode(.inline)
            .task(id: "\(subjectID)|\(model.dataRevision)") { await load() }
            .recordEntry($recording)
            .sheet(item: $editing) { exam in if let scope = model.scope { ExamEditorView(scope: scope,existing: exam) } }
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

struct ExamTrendCard: View {
    let subject: Subject
    let exams: [Exam]
    @Environment(AppModel.self) private var model
    @State private var metric = 0
    @State private var selectedPosition: Double?
    var selectedMetric: ExamTimeline.Metric { [.score,.classRank,.gradeRank,.districtRank][metric] }
    var points: [ExamTimeline.Point] { ExamTimeline.points(exams,metric: selectedMetric) }
    var allPoints: [ExamTimeline.Point] { ExamTimeline.points(exams,metric: selectedMetric,maximumPoints: Int.max) }
    var highlighted: ExamTimeline.Point? {
        guard let selectedPosition else { return allPoints.last }
        return allPoints.min { abs(Double($0.position)-selectedPosition) < abs(Double($1.position)-selectedPosition) }
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 20) {
            Picker("趋势指标",selection: $metric) { Text("分数").tag(0); Text("班排").tag(1); Text("年排").tag(2); Text("区排").tag(3) }.pickerStyle(.segmented)
            if let point = highlighted {
                VStack(alignment: .leading,spacing: 6) {
                    HStack(alignment: .firstTextBaseline,spacing: 5) {
                        Text(metric == 0 ? Score.text(point.exam.score) : "\(Int(point.value))").font(.system(.largeTitle,design: .rounded,weight: .bold)).monospacedDigit().foregroundStyle(model.accent)
                        Text(metric == 0 ? "分" : "名").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("第 \(point.position) 次").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(point.exam.name.isEmpty ? point.exam.type.label : point.exam.name) · \(point.exam.date.description)").font(.subheadline).foregroundStyle(.secondary)
                }.accessibilityIdentifier("analysis.selection")
                trendChart
                Label(metric == 0 ? "横轴按考试先后排列 · 轻按或拖动查看" : "排名越小越好 · 缺失的排名不补零",systemImage: "hand.draw").font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView("还没有这类排名",systemImage: "list.number",description: Text("编辑成绩时可以补充排名。"))
            }
        }.studySurface().onChange(of: metric) { _,_ in selectedPosition = nil }.sensoryFeedback(.selection,trigger: metric)
    }
    var trendChart: some View {
        Chart {
            ForEach(points) { point in
                if metric == 0 {
                    AreaMark(x: .value("考试序号",Double(point.position)),yStart: .value("起点",0),yEnd: .value("分数",point.value))
                        .foregroundStyle(LinearGradient(colors: [model.accent.opacity(0.20),model.accent.opacity(0.01)],startPoint: .top,endPoint: .bottom))
                }
                LineMark(x: .value("考试序号",Double(point.position)),y: .value(metric == 0 ? "分数" : "排名",point.value))
                    .foregroundStyle(model.accent).lineStyle(StrokeStyle(lineWidth: 2.5,lineCap: .round,lineJoin: .round))
                PointMark(x: .value("考试序号",Double(point.position)),y: .value("数值",point.value)).symbolSize(exams.count > 40 ? 12 : 42).foregroundStyle(model.accent)
                    .accessibilityLabel("第 \(point.position) 次，\(point.exam.date.description)，\(point.exam.name)，\(metric == 0 ? Score.text(point.exam.score) + " 分" : String(Int(point.value)) + " 名")")
            }
            if let selectedPosition, let point = highlighted {
                RuleMark(x: .value("选择",Double(point.position))).foregroundStyle(.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4,4]))
                PointMark(x: .value("选择",Double(point.position)),y: .value("数值",point.value)).symbolSize(80).foregroundStyle(model.accent)
            }
        }
        .chartXScale(domain: 0.65...Double(max(1,exams.count))+0.35)
        .chartYScale(domain: metric == 0 ? [0,Double(subject.fullScore)/100] : [max(2,points.map(\.value).max() ?? 2),1])
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                AxisTick()
                AxisValueLabel { if let index = value.as(Double.self) { Text("第\(Int(index))次").font(.caption2) } }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading,values: yTicks) { value in
                AxisGridLine(stroke: StrokeStyle(dash: [3,4])).foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel { if let number = value.as(Double.self) { Text(number,format: .number.precision(.fractionLength(0...2))).font(.caption2) } }
            }
        }
        .chartXSelection(value: $selectedPosition).frame(height: 220).padding(.top,4)
        .accessibilityIdentifier("analysis.chart")
    }
    var xTicks: [Double] {
        let count = exams.count
        if count <= 5 { return (1...max(1,count)).map(Double.init) }
        return [1,Double((count+1)/2),Double(count)]
    }
    var yTicks: [Double] {
        if metric == 0 { return (0...4).map { Double(subject.fullScore)/100*Double($0)/4 } }
        let maximum = max(2,Int(points.map(\.value).max() ?? 2))
        let step = max(1,Int(ceil(Double(maximum)/4)))
        return Array(Set([1.0,Double(maximum)] + stride(from: step,through: maximum,by: step).map(Double.init))).sorted()
    }
}
