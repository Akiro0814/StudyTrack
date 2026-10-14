import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var add = false
    @State private var batch = false
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading,spacing: 8) {
                    Text(model.currentUser?.name ?? "").font(.largeTitle.bold())
                    Text(model.currentSemester?.name ?? "").foregroundStyle(.secondary)
                }.padding(.vertical,12)
            }
            Section("本学期概览") {
                SummaryView(summary: model.home.summary)
                LabeledContent("科目",value: "\(model.subjects.count)")
                LabeledContent("考试记录",value: "\(model.home.total)")
            }
            Section {
                AddExamButton { add = true }.disabled(model.subjects.isEmpty)
                Button("批量录入",systemImage: "square.stack.3d.up") { batch = true }.disabled(model.subjects.isEmpty)
                if model.subjects.isEmpty { Text("先到“科目”添加一个科目，再记录第一场考试。").foregroundStyle(.secondary) }
            }
            Section("最近成绩") {
                if model.home.rows.isEmpty { ContentUnavailableView("暂无成绩",systemImage: "pencil.and.list.clipboard",description: Text("每次考试后，留下一条记录。")) }
                ForEach(model.home.rows) { exam in ExamRowView(exam: exam,subjects: model.subjects) }
            }
        }.navigationTitle("学迹").refreshable { do { try await model.reload() } catch { model.error = model.friendly(error) } }
            .sheet(isPresented: $add) { ExamEditorView(scope: model.scope!,existing: nil) }
            .sheet(isPresented: $batch) { BatchEditorView(scope: model.scope!) }
    }
}
