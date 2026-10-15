import SwiftUI
import PhotosUI
import StudyTrackCore

struct SchoolTermPicker: View {
    @Binding var term: SchoolTerm
    var body: some View {
        Picker("学习阶段",selection: Binding(get: { term.stage },set: { term = SchoolTerm(stage: $0,year: 1,half: 1) })) {
            ForEach(SchoolStage.allCases) { Text($0.label).tag($0) }
        }.accessibilityIdentifier("semester.stage")
        Picker("学期",selection: $term) {
            ForEach(SchoolTerm.catalog(for: term.stage)) { Text($0.label).tag($0) }
        }.accessibilityIdentifier("semester.term")
    }
}

struct ProfileSetupForm: View {
    @Environment(AppModel.self) private var model
    var onboarding = false
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var term = SchoolTerm(stage: .high,year: 1,half: 1)
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var avatar: Asset?
    @State private var photoLoading = false
    @State private var failure: String?
    @FocusState private var editing: Bool
    var body: some View {
        Form {
            if onboarding {
                Section {
                    VStack(alignment: .leading,spacing: 20) {
                        BrandMark(size: 72)
                        Text("把努力，\n写成看得见的成长。").font(.largeTitle.bold()).fixedSize(horizontal: false,vertical: true)
                        Text("欢迎来到学迹 StudyTrack\n为你珍藏每一次考试、每一步变化。").font(.subheadline).foregroundStyle(.secondary).lineSpacing(5)
                    }.padding(.vertical,20)
                }.listRowBackground(Color.clear)
            }
            Section {
                PhotosPicker(selection: $item,matching: .images) {
                    HStack(spacing: 16) {
                        Group {
                            if let image { Image(uiImage: image).resizable().scaledToFill() }
                            else { Image(systemName: "person.crop.circle.badge.plus").resizable().scaledToFit().padding(8) }
                        }.frame(width: 64,height: 64).clipShape(Circle())
                        VStack(alignment: .leading,spacing: 5) { Text(image == nil ? "设置头像" : "更换头像"); Text("也可以稍后在个人资料中设置").font(.caption).foregroundStyle(.secondary) }
                        if photoLoading { ProgressView() }
                    }.padding(.vertical,8)
                }.accessibilityIdentifier("onboarding.avatar")
                TextField("姓名或昵称",text: $name).textContentType(.nickname).focused($editing).submitLabel(.done).onSubmit { editing = false }.accessibilityIdentifier("onboarding.name").padding(.vertical,8)
                SchoolTermPicker(term: $term)
                InlineError(message: failure)
                Button {
                    editing = false
                    Task {
                        if await model.perform(onError: { failure = $0 }, {
                            _ = try await model.store?.createProfile(name: name,term: term,avatar: avatar)
                            model.selectionRevision += 1
                        }) { dismiss() }
                    }
                } label: {
                    HStack { Text(onboarding ? "开启我的学迹" : "创建学习档案"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).frame(maxWidth: .infinity).padding(.vertical,10)
                }.buttonStyle(StudyPrimaryButtonStyle()).buttonBorderShape(.capsule).accessibilityIdentifier("onboarding.start")
                    .disabled(normalize(name).isEmpty || photoLoading)
                    .listRowInsets(EdgeInsets(top: 16,leading: 16,bottom: 16,trailing: 16))
            } header: { Text("从你的学习档案开始") } footer: { Text("无需注册 · 本机保存 · 支持完整备份") }
        }.studyCanvas().navigationTitle(onboarding ? "" : "添加用户").navigationBarTitleDisplayMode(.inline)
            .onChange(of: item) { _,value in
                guard let value else { return }; editing = false; photoLoading = true; failure = nil
                Task {
                    defer { photoLoading = false }
                    do {
                        guard let data = try await value.loadTransferable(type: Data.self), let files = model.files else { throw StudyError.invalid("照片未能下载，请重试。") }
                        avatar = try await files.saveAvatar(data); image = UIImage(data: data)
                    } catch { failure = model.friendly(error) }
                }
            }
    }
}
