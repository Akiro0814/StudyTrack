import SwiftUI
import StudyTrackCore

struct ExamsView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var subjectID = ""
    @State private var page = ExamPage.empty
    @State private var loading = true
    @State private var loadError: String?
    @State private var editing: Exam?
    @State private var recording: RecordIntent?
    @State private var deleting: Exam?
    @State private var requestID = UUID()
    var filterKey: String { "\(model.dataRevision)|\(search)|\(subjectID)" }
    var body: some View {
        List {
            Section {
                SubjectFilter(selection: $subjectID)
                HStack { Text("\(page.total)").font(.system(.largeTitle,design: .rounded,weight: .bold)); Text("份努力，已被记录").font(.subheadline).foregroundStyle(.secondary); Spacer() }.padding(.top,8)
            }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            if loading && page.rows.isEmpty { ProgressView("正在读取成绩").listRowBackground(Color.clear) }
            else if let loadError {
                EmptyStudyView(title: "读取暂未完成",message: loadError,symbol: "arrow.clockwise",actionTitle: "重试") { Task { await load(reset: true) } }.listRowBackground(Color.clear)
            } else {
                if !page.rows.isEmpty { Section { VStack(alignment: .leading,spacing: 12) { SummaryView(summary: page.summary) }.studySurface() }.listRowBackground(Color.clear).listRowSeparator(.hidden) }
                if page.rows.isEmpty {
                    let filtered = !search.isEmpty || !subjectID.isEmpty
                    EmptyStudyView(title: filtered ? "还没找到这条足迹" : "为下一次进步起笔",message: filtered ? "试试其他科目或考试名称。" : "录下成绩、排名与想法，回看自己的成长。",symbol: filtered ? "magnifyingglass" : "pencil.and.list.clipboard",actionTitle: filtered ? "清除筛选" : "添加成绩") {
                        if filtered { search = ""; subjectID = "" } else { recording = .single }
                    }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                Section {
                    ForEach(page.rows) { exam in
                        Button { editing = exam } label: { ExamRowView(exam: exam,subjects: model.subjects).foregroundStyle(.primary).padding(.vertical,8) }
                            .swipeActions { Button("删除",role: .destructive) { deleting = exam }; Button("编辑") { editing = exam }.tint(model.accent) }
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).opacity(model.wallpaper == nil ? 1 : 0.85))
                    }
                } header: { if !page.rows.isEmpty { Text("按考试日期 · 最近在前").textCase(nil) } }
                if page.rows.count < page.total { Button { Task { await load(reset: false) } } label: { HStack { Spacer(); if loading { ProgressView() } else { Text("再看 50 条") }; Spacer() } }.disabled(loading).listRowBackground(Color.clear) }
            }
        }.listSectionSpacing(18).studyCanvas().navigationTitle("成绩").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search,prompt: "搜索考试名称")
            .toolbar {
                Menu { Button("添加成绩",systemImage: "plus") { recording = .single }; Button("批量录入",systemImage: "square.stack.3d.up") { recording = .batch } } label: { Image(systemName: "plus") }.accessibilityLabel("添加成绩")
            }
            .task(id: filterKey) { do { try await Task.sleep(for: .milliseconds(180)); try Task.checkCancellation(); await load(reset: true) } catch {} }
            .refreshable { await load(reset: true) }.recordEntry($recording)
            .sheet(item: $editing) { exam in if let scope = model.scope { ExamEditorView(scope: scope,existing: exam) } }
            .confirmationDialog("删除这条成绩？此操作不可撤销。",isPresented: Binding(get: { deleting != nil },set: { if !$0 { deleting = nil } }),titleVisibility: .visible) {
                Button("删除成绩",role: .destructive) {
                    guard let exam = deleting, let scope = model.scope else { return }
                    Task { _ = await model.perform { try await model.store?.deleteExam(id: exam.id,scope: scope) } }; deleting = nil
                }
            }
    }
    func load(reset: Bool) async {
        guard let store = model.store, let scope = model.scope else { return }
        let id = UUID(); requestID = id; loading = true; loadError = nil
        if reset { page = .empty }
        do {
            let next = try await store.exams(scope: scope,filter: ExamFilter(subjectID: subjectID.isEmpty ? nil : subjectID,search: search),offset: reset ? 0 : page.rows.count,limit: 50)
            guard requestID == id, scope == model.scope, !Task.isCancelled else { return }
            page = ExamPage(rows: reset ? next.rows : page.rows+next.rows,total: next.total,summary: next.summary); loading = false
        } catch { if requestID == id { loadError = model.friendly(error); loading = false } }
    }
}
