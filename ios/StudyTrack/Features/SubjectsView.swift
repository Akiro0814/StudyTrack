import SwiftUI
import StudyTrackCore

struct SubjectsView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Subject?
    @State private var editor = false
    @State private var deleting: Subject?
    @State private var counts: [String: Int] = [:]
    var body: some View {
        List {
            if model.subjects.isEmpty { ContentUnavailableView("还没有科目",systemImage: "books.vertical",description: Text("添加数学、语文等科目，并设置满分。")) }
            ForEach(model.subjects) { subject in
                Button { editing = subject; editor = true } label: {
                    HStack {
                        VStack(alignment: .leading,spacing: 6) { Text(subject.name).font(.headline); Text("满分 \(Score.text(subject.fullScore)) · \(counts[subject.id] ?? 0) 条记录").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }.foregroundStyle(.primary).padding(.vertical,6)
                }.swipeActions { Button("删除",role: .destructive) { deleting = subject } }
            }
        }.navigationTitle("科目")
            .toolbar { Button("添加科目",systemImage: "plus") { editing = nil; editor = true }.accessibilityIdentifier("subjects.add") }
            .sheet(isPresented: $editor) { SubjectEditorView(scope: model.scope!,subject: editing) }
            .confirmationDialog("删除科目及其 \(counts[deleting?.id ?? ""] ?? 0) 条成绩？",isPresented: Binding(get: { deleting != nil },set: { if !$0 { deleting = nil } }),titleVisibility: .visible) {
                Button("删除科目与成绩",role: .destructive) {
                    guard let subject = deleting, let scope = model.scope else { return }
                    Task { _ = await model.perform { try await model.store?.deleteSubject(id: subject.id,scope: scope) } }; deleting = nil
                }
            }
            .task(id: model.home.total.description + model.subjects.map(\.updatedAt).joined()) {
                guard let store = model.store, let scope = model.scope else { return }
                do {
                    var result: [String: Int] = [:]
                    for subject in model.subjects { result[subject.id] = try await store.exams(scope: scope,filter: ExamFilter(subjectID: subject.id),offset: 0,limit: 1).total }
                    if model.scope == scope { counts = result }
                } catch { model.error = model.friendly(error) }
            }
    }
}

struct SubjectEditorView: View {
    let scope: StudyScope; let subject: Subject?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fullScore = "100"
    @State private var failure: String?
    @State private var discard = false
    @FocusState private var focused: Bool
    var dirty: Bool { name != (subject?.name ?? "") || fullScore != (subject.map { Score.text($0.fullScore) } ?? "100") }
    var body: some View {
        NavigationStack {
            Form {
                TextField("科目名称",text: $name).focused($focused).accessibilityIdentifier("subject.name")
                TextField("满分",text: $fullScore).keyboardType(.decimalPad).accessibilityIdentifier("subject.fullScore")
                InlineError(message: failure)
            }.navigationTitle(subject == nil ? "添加科目" : "编辑科目")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { if dirty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.accessibilityIdentifier("subject.save") }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { focused = false } }
                }.interactiveDismissDisabled(dirty).background(DismissGuard(isDirty: dirty) { discard = true })
                .confirmationDialog("放弃未保存的修改？",isPresented: $discard,titleVisibility: .visible) { Button("放弃",role: .destructive) { dismiss() } }
        }.onAppear { name = subject?.name ?? ""; fullScore = subject.map { Score.text($0.fullScore) } ?? "100" }
    }
    func save() async {
        do {
            let full = try Score.parse(fullScore,decimalSeparator: Locale.current.decimalSeparator ?? ".")
            guard model.scope == scope else { throw StudyError.scopeChanged }
            if await model.perform(onError: { failure = $0; focused = true }, { _ = try await model.store?.saveSubject(id: subject?.id,name: name,fullScore: full,scope: scope) }) { dismiss() }
        } catch { failure = error.localizedDescription; focused = true }
    }
}
