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
            Section {
                VStack(alignment: .leading,spacing: 6) { Text("每一科，都有自己的轨迹。").font(.title2.bold()); Text("\(model.subjects.count) 个科目 · 轻点管理，左滑删除").font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical,8)
            }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            if model.subjects.isEmpty {
                EmptyStudyView(title: "先为学习留一个位置",message: "添加科目、设置满分，开始记录你的第一场考试。",symbol: "books.vertical",actionTitle: "添加科目") { editing = nil; editor = true }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(model.subjects) { subject in
                Button { editing = subject; editor = true } label: {
                    HStack(spacing: 16) {
                        Image(systemName: subject.name.contains("数") ? "function" : subject.name.contains("英") ? "character.book.closed" : "book.closed").font(.title2).foregroundStyle(.tint)
                            .frame(width: 52,height: 58).background(.tint.opacity(0.10),in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading,spacing: 6) { Text(subject.name).font(.headline); Text("满分 \(Score.text(subject.fullScore)) · \(counts[subject.id] ?? 0) 条记录").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }.foregroundStyle(.primary).studySurface()
                }.buttonStyle(.plain).listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 6,leading: 20,bottom: 6,trailing: 20))
                    .swipeActions { Button("删除",role: .destructive) { deleting = subject } }
            }
        }.listStyle(.plain).studyCanvas().navigationTitle("科目").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("添加科目",systemImage: "plus") { editing = nil; editor = true }.accessibilityIdentifier("subjects.add") }
            .sheet(isPresented: $editor) { if let scope = model.scope { SubjectEditorView(scope: scope,subject: editing) } }
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
    var onSaved: (() -> Void)? = nil
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fullScore = "100"
    @State private var failure: String?
    @State private var discard = false
    @FocusState private var field: String?
    var dirty: Bool { name != (subject?.name ?? "") || fullScore != (subject.map { Score.text($0.fullScore) } ?? "100") }
    var body: some View {
        NavigationStack {
            Form {
                Section("科目名称") {
                    TextField("例如：数学",text: $name).font(.title3.weight(.medium)).focused($field,equals: "name").submitLabel(.next).onSubmit { field = "full" }.accessibilityIdentifier("subject.name")
                    if subject == nil {
                        ScrollView(.horizontal) { HStack { ForEach(["语文","数学","英语","物理","化学","生物"],id: \.self) { suggestion in Button(suggestion) { name = suggestion }.buttonStyle(.bordered).buttonBorderShape(.capsule) } } }.scrollIndicators(.hidden)
                    }
                }
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("满分",text: $fullScore).font(.system(.largeTitle,design: .rounded,weight: .semibold)).keyboardType(.decimalPad).focused($field,equals: "full").accessibilityIdentifier("subject.fullScore")
                        Text("分").foregroundStyle(.secondary)
                    }.padding(.vertical,8)
                } header: { Text("这门科目的满分") } footer: { Text("不同科目可设置不同满分。修改满分不会改变已记录的分数。") }
                InlineError(message: failure)
            }.studyCanvas().navigationTitle(subject == nil ? "添加科目" : "编辑科目").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { if dirty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.accessibilityIdentifier("subject.save") }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { field = nil } }
                }.interactiveDismissDisabled(dirty).background(DismissGuard(isDirty: dirty) { discard = true })
                .confirmationDialog("放弃未保存的修改？",isPresented: $discard,titleVisibility: .visible) { Button("放弃",role: .destructive) { dismiss() } }
        }.onAppear { name = subject?.name ?? ""; fullScore = subject.map { Score.text($0.fullScore) } ?? "100" }
    }
    func save() async {
        do {
            let full = try Score.parse(fullScore,decimalSeparator: Locale.current.decimalSeparator ?? ".")
            guard model.scope == scope else { throw StudyError.scopeChanged }
            if await model.perform(onError: { failure = $0; field = "name" }, { _ = try await model.store?.saveSubject(id: subject?.id,name: name,fullScore: full,scope: scope) }) { onSaved?(); dismiss() }
        } catch { failure = error.localizedDescription; field = "full" }
    }
}
