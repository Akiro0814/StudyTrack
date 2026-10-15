import SwiftUI
import Charts
import StudyTrackCore

struct AnalysisView: View {
    @Environment(AppModel.self) private var model
    @State private var data = AnalysisData()
    @State private var wholeStage = false
    @State private var groupID = ""
    @State private var search = ""
    @State private var loading = false
    @State private var failure: String?
    @State private var recording: RecordIntent?
    @State private var editing: Exam?
    @State private var visibleCounts: [String: Int] = [:]
    var groups: [AnalysisGroup] { data.groups.filter { groupID.isEmpty || $0.id == groupID } }
    var queryKey: String { "\(wholeStage)|\(model.dataRevision)|\(model.selectionRevision)" }
    var body: some View {
        StudyScroll {
            VStack(alignment: .leading,spacing: 10) {
                Text("看见每一步变化。").font(.title2.bold())
                Picker("分析范围",selection: $wholeStage) { Text("本学期").tag(false); Text("学习阶段汇总").tag(true) }.pickerStyle(.segmented)
                Text(wholeStage ? (model.currentSemester?.schoolTerm?.stage.label ?? "请先归类当前学期") + " · 全部已建学期" : model.currentSemester?.name ?? "本学期").font(.caption).foregroundStyle(.secondary)
                Picker("科目",selection: $groupID) {
                    Text("全部科目").tag("")
                    ForEach(data.groups) { Text($0.subject.name + " · " + Score.text($0.subject.fullScore) + "分制").tag($0.id) }
                }.pickerStyle(.menu)
            }
            if loading { ProgressView("正在整理成绩") }
            else if let failure { EmptyStudyView(title: "暂时无法读取",message: failure,symbol: "arrow.clockwise",actionTitle: "重试") { Task { await load() } } }
            else if data.exams.isEmpty { EmptyStudyView(title: "你的曲线，等待起笔",message: "记录考试后，在这里回看成长。",symbol: "chart.xyaxis.line",actionTitle: "添加成绩") { recording = .single } }
            else {
                if groupID.isEmpty {
                    ForEach(Array(Set(groups.filter { !$0.exams.isEmpty }.map { $0.subject.fullScore })).sorted(),id: \.self) { full in
                        MultiSubjectChart(groups: groups.filter { $0.subject.fullScore == full },fullScore: full)
                    }
                } else if let group = groups.first, !group.exams.isEmpty { ExamTrendCard(subject: group.subject,exams: group.exams) }
                ForEach(groups) { group in
                    VStack(alignment: .leading,spacing: 16) {
                        SectionHeading(title: group.subject.name,detail: "满分 \(Score.text(group.subject.fullScore))")
                        SummaryView(summary: group.summary)
                        DisclosureGroup("查看 \(group.exams.count) 条成绩明细") {
                            let rows = group.exams.reversed().filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
                            VStack(spacing: 16) {
                                ForEach(Array(rows.prefix(visibleCounts[group.id] ?? 50))) { exam in
                                    SwipeDeleteRow(action: { Task { await model.deleteRecord(exam) } }) {
                                        Button { editing = exam } label: { ExamRowView(exam: exam,subjects: data.subjects).foregroundStyle(.primary) }.buttonStyle(.plain)
                                    }
                                }
                                if rows.count > (visibleCounts[group.id] ?? 50) { Button("继续查看 50 条") { visibleCounts[group.id] = (visibleCounts[group.id] ?? 50)+50 } }
                            }.padding(.top,16)
                        }
                    }.studySurface()
                }
            }
        }.navigationTitle("成绩分析").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search,prompt: "搜索考试名称")
            .toolbar { Menu { Button("添加成绩",systemImage: "plus") { recording = .single }; Button("批量录入",systemImage: "square.stack.3d.up") { recording = .batch } } label: { Image(systemName: "plus") }.accessibilityLabel("添加成绩") }
            .task(id: queryKey) { await load() }.refreshable { await load() }.recordEntry($recording)
            .onChange(of: model.analysisRoute) { _,route in if let route { wholeStage = route.wholeStage; Task { await load(); if let id = route.subjectID,let group = data.groups.first(where: { $0.subject.id == id || $0.exams.contains(where: { $0.subjectID == id }) }) { groupID = group.id } } } }
            .onAppear { if let route = model.analysisRoute { wholeStage = route.wholeStage } }
            .sheet(item: $editing) { exam in ExamEditorView(scope: StudyScope(userID: exam.userID,semesterID: exam.semesterID),existing: exam) }
    }
    func load() async {
        guard let store = model.store,let scope = model.scope else { return }
        let key = queryKey; loading = true; failure = nil
        do {
            let next = try await store.analysis(scope: scope,wholeStage: wholeStage)
            guard !Task.isCancelled, key == queryKey, scope == model.scope else { return }
            data = next; if !next.groups.contains(where: { $0.id == groupID }) { groupID = "" }
            if let route = model.analysisRoute,let id = route.subjectID,let group = next.groups.first(where: { $0.subject.id == id || $0.exams.contains(where: { $0.subjectID == id }) }) { groupID = group.id }
            visibleCounts = [:]; loading = false
        } catch { if !Task.isCancelled, key == queryKey { failure = model.friendly(error); loading = false } }
    }
}

struct MultiSubjectChart: View {
    let groups: [AnalysisGroup]
    let fullScore: Int64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0
    @State private var selected: Double?
    func color(_ id: String) -> Color {
        let index = groups.firstIndex { $0.id == id } ?? 0
        return Color(hue: (0.61 + Double(index)*0.61803398875).truncatingRemainder(dividingBy: 1),saturation: 0.7,brightness: 0.8)
    }
    var body: some View {
        let timeline = MultiSubjectTimeline(groups: groups)
        VStack(alignment: .leading,spacing: 16) {
            SectionHeading(title: "\(Score.text(fullScore)) 分制",detail: "\(groups.filter { !$0.exams.isEmpty }.count) 科")
            Chart {
                ForEach(timeline.plotted) { point in
                    LineMark(x: .value("日期",point.x),y: .value("分数",point.value),series: .value("科目",point.groupID))
                        .interpolationMethod(.monotone).foregroundStyle(color(point.groupID)).lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("日期",point.x),y: .value("分数",point.value)).foregroundStyle(color(point.groupID)).symbolSize(24)
                        .accessibilityLabel("\(point.exam.date.description)，\(point.exam.name)，\(Score.text(point.exam.score))分")
                }
                if let selected { RuleMark(x: .value("选择",selected)).foregroundStyle(.secondary.opacity(0.5)) }
            }.chartYScale(domain: 0...Double(fullScore)/100)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in AxisValueLabel { if let day = value.as(Double.self) { Text(Date(timeIntervalSince1970: day*86400),format: .dateTime.month().day()).font(.caption2) } } } }
                .chartXSelection(value: $selected)
                .chartPlotStyle { plot in plot.mask(alignment: .leading) { GeometryReader { proxy in Rectangle().frame(width: proxy.size.width * reveal) } } }
                .frame(height: 230).accessibilityIdentifier("analysis.chart")
            if let selected,let point = timeline.all.min(by: { abs($0.x-selected) < abs($1.x-selected) }),let group = groups.first(where: { $0.id == point.groupID }) {
                Text("\(group.subject.name) · \(point.exam.date.description) · \(point.exam.name) · \(Score.text(point.exam.score))分").font(.caption)
            }
            ViewThatFits { HStack { legend }; VStack(alignment: .leading) { legend } }
            Text("按真实日期排列 · 同日考试独立显示").font(.caption).foregroundStyle(.secondary)
        }.studySurface().task(id: timeline.all.map(\.id)) {
            reveal = reduceMotion ? 1 : 0
            guard !reduceMotion else { return }
            do { try await Task.sleep(for: .milliseconds(70)); try Task.checkCancellation() } catch { return }
            withAnimation(.easeInOut(duration: 0.8)) { reveal = 1 }
        }
    }
    @ViewBuilder var legend: some View { ForEach(groups.filter { !$0.exams.isEmpty }) { group in Label { Text(group.subject.name) } icon: { Circle().fill(color(group.id)).frame(width: 8,height: 8) }.font(.caption) } }
}

struct ExamTrendCard: View {
    let subject: Subject
    let exams: [Exam]
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var metric = 0
    @State private var selectedPosition: Double?
    @State private var reveal: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .task(id: "\(metric)|\(exams.map(\.id))") {
                reveal = reduceMotion ? 1 : 0
                guard !reduceMotion else { return }
                do { try await Task.sleep(for: .milliseconds(70)); try Task.checkCancellation() } catch { return }
                withAnimation(.easeInOut(duration: 0.8)) { reveal = 1 }
            }
    }
    var trendChart: some View {
        Chart {
            ForEach(points) { point in
                if metric == 0 {
                    AreaMark(x: .value("考试序号",Double(point.position)),yStart: .value("起点",0),yEnd: .value("分数",point.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [model.accent.opacity(0.20),model.accent.opacity(0.01)],startPoint: .top,endPoint: .bottom))
                }
                LineMark(x: .value("考试序号",Double(point.position)),y: .value(metric == 0 ? "分数" : "排名",point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(model.accent).lineStyle(StrokeStyle(lineWidth: 2.5,lineCap: .round,lineJoin: .round))
                PointMark(x: .value("考试序号",Double(point.position)),y: .value("数值",point.value)).symbolSize(exams.count > 40 ? 12 : 42).foregroundStyle(model.accent)
                    .accessibilityLabel("第 \(point.position) 次，\(point.exam.date.description)，\(point.exam.name)，\(metric == 0 ? Score.text(point.exam.score) + " 分" : String(Int(point.value)) + " 名")")
            }
            if selectedPosition != nil, let point = highlighted {
                RuleMark(x: .value("选择",Double(point.position))).foregroundStyle(.secondary.opacity(0.4)).lineStyle(StrokeStyle(dash: [4,4]))
                PointMark(x: .value("选择",Double(point.position)),y: .value("数值",point.value)).symbolSize(80).foregroundStyle(model.accent)
            }
        }
        .chartXScale(domain: 0.65...Double(max(1,exams.count))+0.35)
        .chartYScale(domain: metric == 0 ? [0,Double(subject.fullScore)/100] : [max(2,points.map(\.value).max() ?? 2),1])
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                AxisTick()
                AxisValueLabel(anchor: .top) { if let index = value.as(Double.self) { Text("\(Int(index))").font(.caption2).fixedSize() } }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading,values: yTicks) { value in
                AxisGridLine(stroke: StrokeStyle(dash: [3,4])).foregroundStyle(.secondary.opacity(0.15))
                AxisValueLabel { if let number = value.as(Double.self) { Text(number,format: .number.precision(.fractionLength(0...2))).font(.caption2) } }
            }
        }
        .chartXSelection(value: $selectedPosition).frame(height: 220).padding(.top,4)
        .chartPlotStyle { plot in plot.mask(alignment: .leading) { GeometryReader { proxy in Rectangle().frame(width: proxy.size.width * reveal) } } }
        .accessibilityIdentifier("analysis.chart")
    }
    var xTicks: [Double] {
        let count = exams.count
        if typeSize.isAccessibilitySize && count > 1 { return [1,Double(count)] }
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
