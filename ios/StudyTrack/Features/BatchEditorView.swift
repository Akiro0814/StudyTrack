import SwiftUI
import StudyTrackCore

struct BatchRow: Identifiable, Codable, Equatable { var id = UUID(); var draft = ExamDraft() }
struct BatchDraft: Codable, Equatable { var name = ""; var date = Date(); var type = ExamType.monthly; var rows = [BatchRow()] }
struct BatchEditorView: View {
    let scope: StudyScope
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BatchDraft()
    @State private var original = BatchDraft()
    @State private var loaded = false
    @State private var discard = false
    @State private var recovered: BatchDraft?
    @State private var failure: String?
    @State private var draftTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focus: String?
    var key: String { "batch:\(scope.userID):\(scope.semesterID)" }
    var body: some View {
        NavigationStack {
            Form {
                Section("同一次考试") {
                    TextField("考试名称",text: $draft.name)
                    Picker("类型",selection: $draft.type) { ForEach(ExamType.allCases,id: \.self) { Text($0.label).tag($0) } }
                    DatePicker("日期",selection: $draft.date,displayedComponents: .date)
                }
                ForEach($draft.rows) { $row in
                    Section {
                        Picker("科目",selection: $row.draft.subjectID) { Text("请选择").tag(""); ForEach(model.subjects) { Text($0.name).tag($0.id) } }
                        TextField("分数",text: $row.draft.score).font(.system(.title,design: .rounded,weight: .semibold)).keyboardType(.decimalPad).focused($focus,equals: row.id.uuidString+".score")
                        DisclosureGroup("补充排名（可选）") {
                            TextField("班排（可选）",text: $row.draft.classRank).keyboardType(.numberPad).focused($focus,equals: row.id.uuidString+".class")
                            TextField("年排（可选）",text: $row.draft.gradeRank).keyboardType(.numberPad).focused($focus,equals: row.id.uuidString+".grade")
                            TextField("区排（可选）",text: $row.draft.districtRank).keyboardType(.numberPad).focused($focus,equals: row.id.uuidString+".district")
                        }
                        Button("移除此行",role: .destructive) { draft.rows.removeAll { $0.id == row.id } }
                    }
                }
                Button("添加一行",systemImage: "plus") { draft.rows.append(BatchRow()) }
                InlineError(message: failure)
                Text("每个科目只能出现一次；所有行校验通过后一次保存，失败不会留下部分成绩。").font(.caption).foregroundStyle(.secondary)
            }.studyCanvas().navigationTitle("批量录入").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { if draft != original { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存全部") { Task { await save() } } }
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("下一行") { if let focus, let i = draft.rows.firstIndex(where: { focus.hasPrefix($0.id.uuidString) }), i+1 < draft.rows.count { self.focus = draft.rows[i+1].id.uuidString+".score" } }
                        Spacer(); Button("完成") { focus = nil }
                    }
                }.interactiveDismissDisabled(draft != original).background(DismissGuard(isDirty: draft != original) { discard = true })
                .confirmationDialog("放弃未保存的批量成绩？",isPresented: $discard,titleVisibility: .visible) {
                    Button("放弃",role: .destructive) { draftTask?.cancel(); loaded = false; Task { try? await model.store?.setDraft(key: key,data: nil); dismiss() } }
                }
                .confirmationDialog("继续上次的批量录入？",isPresented: Binding(get: { recovered != nil },set: { if !$0 { recovered = nil } }),titleVisibility: .visible) {
                    Button("恢复草稿") { if let recovered { draft = recovered }; recovered = nil }
                    Button("丢弃",role: .destructive) { recovered = nil; Task { try? await model.store?.setDraft(key: key,data: nil) } }
                }
        }.task {
            if let first = model.subjects.first { draft.rows[0].draft.subjectID = first.id }
            original = draft
            if let data = try? await model.store?.draft(key: key), let saved = try? JSONDecoder().decode(BatchDraft.self,from: data) { recovered = saved }
            loaded = true
        }.onChange(of: draft) { _, _ in if loaded { persistDraft() } }
            .onChange(of: scenePhase) { _,phase in if phase != .active && loaded { persistDraft() } }
    }
    func persistDraft() {
        draftTask?.cancel(); let data = try? JSONEncoder().encode(draft)
        draftTask = Task { try? await Task.sleep(for: .milliseconds(150)); guard !Task.isCancelled else { return }; try? await model.store?.setDraft(key: key,data: data) }
    }
    func save() async {
        do {
            guard model.scope == scope else { throw StudyError.scopeChanged }
            guard !draft.rows.isEmpty, Set(draft.rows.map { $0.draft.subjectID }).count == draft.rows.count else { throw StudyError.invalid("至少填写一行，同批次科目不能重复。") }
            let inputs = try draft.rows.enumerated().map { i,row -> ExamInput in
                var value = row.draft; value.name = draft.name; value.date = draft.date; value.type = draft.type
                do { return try value.input() } catch { throw StudyError.invalid("第 \(i+1) 行：\(error.localizedDescription)") }
            }
            draftTask?.cancel()
            if await model.perform(onError: { failure = $0 }, { _ = try await model.store?.saveExams(inputs,scope: scope); try await model.store?.setDraft(key: key,data: nil) }) { loaded = false; original = draft; dismiss() }
        } catch { failure = error.localizedDescription }
    }
}
