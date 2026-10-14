import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var semester = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.tint).padding(.vertical,12)
                    Text("每一次记录，\n都看得到进步。").font(.largeTitle.bold())
                    Text("学迹在本机保存你的科目、考试和反思。先创建一份学习档案。").foregroundStyle(.secondary)
                }
                Section("你的学习档案") {
                    TextField("姓名或昵称",text: $name).accessibilityIdentifier("onboarding.name")
                    TextField("学期，例如：高一上学期",text: $semester).accessibilityIdentifier("onboarding.semester")
                }
                Section {
                    Button("开始记录") {
                        Task { _ = await model.perform { _ = try await model.store?.createUser(name: name,semester: semester) } }
                    }.accessibilityIdentifier("onboarding.start").disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: { Text("本地用户档案无需注册。请定期导出完整备份。") }
            }.navigationTitle("欢迎使用学迹")
        }
    }
}
