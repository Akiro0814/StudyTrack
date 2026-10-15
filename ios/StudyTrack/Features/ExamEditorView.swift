import SwiftUI
import StudyTrackCore

struct ExamDraft: Codable, Equatable {
    var subjectID = ""; var name = ""; var date = Date(); var score = ""; var type = ExamType.monthly
    var classRank = ""; var gradeRank = ""; var districtRank = ""; var reflection = ""
    init() {}
    init(_ exam: Exam) {
        subjectID = exam.subjectID; name = exam.name; date = exam.date.date; score = Score.text(exam.score); type = exam.type
        classRank = exam.classRank.map(String.init) ?? ""; gradeRank = exam.gradeRank.map(String.init) ?? ""
        districtRank = exam.districtRank.map(String.init) ?? ""; reflection = exam.reflection ?? ""
    }
    func input(id: String? = nil) throws -> ExamInput {
        guard !subjectID.isEmpty else { throw StudyError.invalid("请选择科目。") }
        return ExamInput(id: id,subjectID: subjectID,name: name,date: LocalDate(date: date),score: try Score.parse(score,decimalSeparator: Locale.current.decimalSeparator ?? "."),type: type,classRank: try Score.rank(classRank),gradeRank: try Score.rank(gradeRank),districtRank: try Score.rank(districtRank),reflection: reflection.isEmpty ? nil : reflection)
    }
}

struct ExamEditorView: View {
    let scope: StudyScope; let existing: Exam?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ExamDraft()
    @State private var original = ExamDraft()
    @State private var failure: String?
    @State private var discard = false
    @State private var recovered: ExamDraft?
    @State private var loaded = false
    @State private var showingRanks = false
    @State private var draftTask: Task<Void, Never>?
    @State private var availableSubjects: [Subject] = []
    @State private var selectionAtOpen: StudyScope?
    @FocusState private var field: String?
    var key: String { "exam:\(scope.userID):\(scope.semesterID):\(existing?.id ?? "new")" }
    var dirty: Bool { draft != original }
    var body: some View {
        NavigationStack {
            Form {
                Section("考试") {
                    Picker("科目",selection: $draft.subjectID) {
                        Text("请选择").tag("")
                        ForEach(availableSubjects) { Text($0.name).tag($0.id) }
                    }
                    if availableSubjects.isEmpty { NavigationLink("先添加科目") { SubjectEditorView(scope: scope,subject: nil) } }
                    Picker("类型",selection: $draft.type) { ForEach(ExamType.allCases,id: \.self) { Text($0.label).tag($0) } }
                    TextField("考试名称（留空使用类型名称）",text: $draft.name).focused($field,equals: "name").submitLabel(.next).onSubmit { field = "score" }
                    DatePicker("日期",selection: $draft.date,displayedComponents: .date)
                }
                Section("成绩") {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("分数",text: $draft.score).font(.system(.largeTitle,design: .rounded,weight: .bold)).keyboardType(.decimalPad).focused($field,equals: "score").accessibilityIdentifier("exam.score")
                        Text("分").foregroundStyle(.secondary)
                    }.padding(.vertical,12)
                    if let subject = availableSubjects.first(where: { $0.id == draft.subjectID }) { Text("满分 \(Score.text(subject.fullScore))").font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    DisclosureGroup("补充排名（可选）",isExpanded: $showingRanks) {
                        LabeledContent("班级") { TextField("未填写",text: $draft.classRank).multilineTextAlignment(.trailing).keyboardType(.numberPad).focused($field,equals: "class") }
                        LabeledContent("年级") { TextField("未填写",text: $draft.gradeRank).multilineTextAlignment(.trailing).keyboardType(.numberPad).focused($field,equals: "grade") }
                        LabeledContent("区县") { TextField("未填写",text: $draft.districtRank).multilineTextAlignment(.trailing).keyboardType(.numberPad).focused($field,equals: "district") }
                    }
                }
                Section("反思") { TextField("有哪些值得记住的经验？",text: $draft.reflection,axis: .vertical).lineLimit(4...12).focused($field,equals: "reflection") }
                InlineError(message: failure)
            }.studyCanvas().navigationTitle(existing == nil ? "添加成绩" : "编辑成绩").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { if dirty { discard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(model.busy || !loaded).accessibilityIdentifier("exam.save") }
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("下一项") { let fields = showingRanks ? ["name","score","class","grade","district","reflection"] : ["name","score","reflection"]; let i = fields.firstIndex(of: field ?? "") ?? -1; field = fields[(i+1)%fields.count] }
                        Spacer(); Button("完成") { field = nil }
                    }
                }.interactiveDismissDisabled(dirty).background(DismissGuard(isDirty: dirty) { discard = true })
                .confirmationDialog("放弃未保存的修改？",isPresented: $discard,titleVisibility: .visible) {
                    Button("放弃",role: .destructive) { draftTask?.cancel(); loaded = false; Task { try? await model.store?.setDraft(key: key,data: nil); dismiss() } }
                }
                .confirmationDialog("发现此用户和学期的未保存草稿",isPresented: Binding(get: { recovered != nil },set: { if !$0 { recovered = nil } }),titleVisibility: .visible) {
                    Button("继续编辑草稿") { if let recovered { draft = recovered }; recovered = nil }
                    Button("丢弃草稿",role: .destructive) { recovered = nil; Task { try? await model.store?.setDraft(key: key,data: nil) } }
                }
        }.task {
            selectionAtOpen = model.scope
            do { availableSubjects = try await model.store?.subjects(scope: scope) ?? [] } catch { failure = model.friendly(error); return }
            draft = existing.map(ExamDraft.init) ?? ExamDraft()
            if existing == nil, let subject = availableSubjects.first { draft.subjectID = subject.id }
            showingRanks = !draft.classRank.isEmpty || !draft.gradeRank.isEmpty || !draft.districtRank.isEmpty
            original = draft
            if let data = try? await model.store?.draft(key: key), let saved = try? JSONDecoder().decode(ExamDraft.self,from: data) { recovered = saved }
            loaded = true
        }.onChange(of: draft) { _, _ in if loaded { persistDraft() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
    }
    func persistDraft() {
        draftTask?.cancel(); let data = try? JSONEncoder().encode(draft)
        draftTask = Task { try? await Task.sleep(for: .milliseconds(150)); guard !Task.isCancelled else { return }; try? await model.store?.setDraft(key: key,data: data) }
    }
    func save() async {
        do {
            guard model.scope == selectionAtOpen,scope.userID == model.scope?.userID else { throw StudyError.scopeChanged }
            let input = try draft.input(id: existing?.id)
            draftTask?.cancel()
            if await model.perform(onError: { failure = $0; field = "score" }, { _ = try await model.store?.saveExams([input],scope: scope); try await model.store?.setDraft(key: key,data: nil) }) { loaded = false; original = draft; dismiss() }
        } catch { failure = error.localizedDescription; field = draft.subjectID.isEmpty ? "name" : "score" }
    }
}
