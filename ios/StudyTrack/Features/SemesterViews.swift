import SwiftUI
import StudyTrackCore

struct SemestersView: View {
    @Environment(AppModel.self) private var model
    @State private var deleting: Semester?
    @State private var confirmDelete = false
    @State private var confirmStage = false
    @State private var upcoming: SchoolStage?
    var body: some View {
        List {
            Section {
                ForEach(model.stageSemesters) { semester in
                    Button { Task { await model.switchScope(StudyScope(userID: semester.userID,semesterID: semester.id)) } } label: {
                        HStack {
                            Text(semester.name); Spacer()
                            if semester.id == model.preferences.currentSemesterID { Image(systemName: "checkmark.circle.fill") }
                        }.padding(.vertical,8)
                    }.swipeActions {
                        Button("删除",role: .destructive) { deleting = semester; confirmDelete = true }
                    }
                }
            } header: { Text(model.currentStage?.label ?? "待归类学期") }
              footer: { Text("这里只切换当前学习阶段的学期。其他阶段和旧学期归类请前往设置中的“学习阶段”。") }
            Section {
                if let next = model.nextSchoolTerm {
                    Text("下一学期：\(next.label)。继承本阶段最近学期的科目和满分，成绩独立保存。").font(.caption).foregroundStyle(.secondary)
                } else { Text("本阶段学期全部创建后，开启下一学期前会询问是否进入下一学习阶段。").font(.caption).foregroundStyle(.secondary) }
            }
        }.studyCanvas().navigationTitle("切换学期").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("开启下一学期") { advance() }.accessibilityIdentifier("semester.next")
                }
            }
            .confirmationDialog("删除学期？仅允许删除非当前且没有科目的学期。",isPresented: $confirmDelete,titleVisibility: .visible) {
                Button("删除学期",role: .destructive) {
                    guard let semester = deleting else { return }
                    Task { _ = await model.perform { try await model.store?.deleteSemester(id: semester.id,userID: semester.userID) } }
                }
            }
            .confirmationDialog("当前阶段的学期已全部创建，是否开启\(upcoming?.label ?? "下一阶段")？",isPresented: $confirmStage,titleVisibility: .visible) {
                if let upcoming { Button("开启\(upcoming.label)") { Task { await model.switchStage(upcoming) } } }
                Button("暂不开启",role: .cancel) {}
            } message: { Text("进入下一阶段后可随时从设置切回。新阶段的成绩与科目独立保存。") }
    }
    func advance() {
        guard let stage = model.currentStage else { model.notice = "请先在“学习阶段”中将旧学期归类。"; return }
        if model.nextSchoolTerm != nil { Task { await model.openNextSemester() } }
        else if let next = stage.next { upcoming = next; confirmStage = true }
        else { model.notice = "大学阶段的全部学期均已创建，已到最后一个学习阶段。" }
    }
}

struct LearningStagesView: View {
    @Environment(AppModel.self) private var model
    @State private var starting: SchoolStage?
    @State private var classifying: Semester?
    @State private var editor = false
    @State private var term = SchoolTerm(stage: .high,year: 1,half: 1)
    @State private var failure: String?
    var body: some View {
        List {
            Section {
                ForEach(SchoolStage.allCases) { stage in
                    let count = model.semesters.filter { $0.schoolTerm?.stage == stage }.count
                    Button {
                        if stage == model.currentStage { return }
                        if count == 0 { starting = stage }
                        else { Task { await model.switchStage(stage) } }
                    } label: {
                        HStack {
                            VStack(alignment: .leading,spacing: 5) {
                                Text(stage.label)
                                Text(count == 0 ? "尚未开启" : "\(count) 个已建学期").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if stage == model.currentStage { Image(systemName: "checkmark.circle.fill") }
                        }.padding(.vertical,6)
                    }.accessibilityIdentifier("stage.\(stage.rawValue)")
                }
            } footer: { Text("切换阶段会进入该阶段最近的已建学期，历史数据始终保留。首次开启阶段将创建第一学期。") }
            let legacy = model.semesters.filter { $0.schoolTerm == nil }
            if !legacy.isEmpty {
                Section("待归类旧学期") {
                    ForEach(legacy) { semester in
                        HStack {
                            Button(semester.name) { Task { await model.switchScope(StudyScope(userID: semester.userID,semesterID: semester.id)) } }
                            Spacer()
                            Button("归类") { classifying = semester; failure = nil; editor = true }.buttonStyle(.bordered)
                        }
                    }
                }
            }
        }.studyCanvas().navigationTitle("学习阶段").navigationBarTitleDisplayMode(.inline)
            .alert("开启学习阶段？",isPresented: Binding(get: { starting != nil },set: { if !$0 { starting = nil } }),presenting: starting) { stage in
                Button("开启\(stage.label)") { Task { await model.switchStage(stage) } }
                Button("取消",role: .cancel) {}
            } message: { stage in Text("将创建\(stage.label)第一学期；其他阶段的科目与成绩不受影响。") }
            .sheet(isPresented: $editor) {
                NavigationStack {
                    Form {
                        SchoolTermPicker(term: $term)
                        Text("保留原学期全部科目与成绩，不会合并已经存在的学期。").font(.caption)
                        InlineError(message: failure)
                    }.studyCanvas().navigationTitle("归类旧学期").toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { editor = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("保存") {
                            guard let semester = classifying else { return }
                            Task {
                                if await model.perform(onError: { failure = $0 }, {
                                    _ = try await model.store?.saveSchoolSemester(id: semester.id,term: term,userID: semester.userID)
                                }) { editor = false }
                            }
                        } }
                    }
                }
            }
    }
}
