import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var semester = ""
    @FocusState private var field: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading,spacing: 20) {
                        BrandMark(size: 72)
                        Text("把努力，\n写成看得见的成长。").font(.system(.largeTitle,design: .rounded,weight: .bold)).fixedSize(horizontal: false,vertical: true)
                        Text("欢迎来到学迹 StudyTrack\n为你珍藏每一次考试、每一步变化。").font(.subheadline).foregroundStyle(.secondary).lineSpacing(5)
                    }.padding(.vertical,20)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0,leading: 0,bottom: 4,trailing: 0))
                Section {
                    TextField("姓名或昵称",text: $name).textContentType(.nickname).focused($field,equals: "name").submitLabel(.next).onSubmit { field = "semester" }.accessibilityIdentifier("onboarding.name").padding(.vertical,8)
                    TextField("例如：高一上学期",text: $semester).focused($field,equals: "semester").submitLabel(.done).onSubmit { field = nil }.accessibilityIdentifier("onboarding.semester").padding(.vertical,8)
                } header: { Text("从你的学习档案开始").textCase(nil) } footer: { Text("无需注册 · 本机保存 · 随时备份").padding(.top,8) }
            }.studyCanvas().safeAreaInset(edge: .bottom,spacing: 0) {
                Button {
                    field = nil
                    Task { _ = await model.perform { _ = try await model.store?.createUser(name: name,semester: semester) } }
                } label: { HStack { Text("开启我的学迹"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).padding(.vertical,7).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule).accessibilityIdentifier("onboarding.start")
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal,24).padding(.vertical,12).background(.bar)
            }.navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { field = nil } } }
        }.containerBackground(for: .navigation) { AppCanvas() }
    }
}
