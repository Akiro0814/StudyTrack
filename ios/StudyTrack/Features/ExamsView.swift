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
    @State private var add = false
    @State private var deleting: Exam?
    @State private var requestID = UUID()
    var filterKey: String { "\(model.selectionRevision)|\(search)|\(subjectID)|\(model.home.total)|\(model.home.rows.first?.updatedAt ?? "")" }
    var body: some View {
        List {
            Section {
                Picker("科目",selection: $subjectID) { Text("全部科目").tag(""); ForEach(model.subjects) { Text($0.name).tag($0.id) } }
            }
            if loading && page.rows.isEmpty { ProgressView("正在读取成绩") }
            else if let loadError { Section { Text(loadError); Button("重试") { Task { await load(reset: true) } } } }
            else {
                Section("\(page.total) 条成绩") { SummaryView(summary: page.summary) }
                if page.rows.isEmpty {
                    ContentUnavailableView("没有符合条件的成绩",systemImage: "magnifyingglass",description: Text("尝试其他科目或考试名称。"))
                    if !search.isEmpty || !subjectID.isEmpty { Button("清除筛选") { search = ""; subjectID = "" } }
                }
                ForEach(page.rows) { exam in
                    Button { editing = exam } label: { ExamRowView(exam: exam,subjects: model.subjects).foregroundStyle(.primary) }
                        .swipeActions { Button("删除",role: .destructive) { deleting = exam } }
                }
                if page.rows.count < page.total { Button("加载更多") { Task { await load(reset: false) } }.disabled(loading) }
            }
        }.navigationTitle("成绩").searchable(text: $search,prompt: "搜索考试名称")
            .toolbar { Button("添加成绩",systemImage: "plus") { add = true } }
            .task(id: filterKey) {
                do { try await Task.sleep(for: .milliseconds(200)); try Task.checkCancellation(); await load(reset: true) } catch {}
            }
            .refreshable { await load(reset: true) }
            .sheet(item: $editing,onDismiss: { Task { await load(reset: true) } }) { ExamEditorView(scope: model.scope!,existing: $0) }
            .sheet(isPresented: $add,onDismiss: { Task { await load(reset: true) } }) { ExamEditorView(scope: model.scope!,existing: nil) }
            .confirmationDialog("删除这条成绩？",isPresented: Binding(get: { deleting != nil },set: { if !$0 { deleting = nil } }),titleVisibility: .visible) {
                Button("删除",role: .destructive) {
                    guard let exam = deleting, let scope = model.scope else { return }
                    Task { if await model.perform({ try await model.store?.deleteExam(id: exam.id,scope: scope) }) { await load(reset: true) } }; deleting = nil
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
