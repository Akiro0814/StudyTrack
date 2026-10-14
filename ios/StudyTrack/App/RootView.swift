import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab = 0
    var body: some View {
        @Bindable var model = model
        Group {
            if !model.ready {
                VStack(spacing: 20) {
                    Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.tint)
                    if model.error == nil { ProgressView("正在打开学迹") }
                    else { Button("重新打开") { Task { await model.start() } } }
                }
            } else if model.users.isEmpty { OnboardingView() }
            else {
                TabView(selection: $selectedTab) {
                    Tab("首页",systemImage: "house",value: 0) { NavigationStack { HomeView() } }
                    Tab("科目",systemImage: "books.vertical",value: 1) { NavigationStack { SubjectsView() } }
                    Tab("成绩",systemImage: "list.bullet.rectangle",value: 2) { NavigationStack { ExamsView() } }
                    Tab("分析",systemImage: "chart.xyaxis.line",value: 3) { NavigationStack { AnalysisView() } }
                    Tab("设置",systemImage: "gearshape",value: 4) { NavigationStack { SettingsView() } }
                }.id(model.selectionRevision)
                    .scrollContentBackground(model.wallpaper != nil && model.preferences.theme == "glass" ? .hidden : .automatic)
                    .background {
                        if let wallpaper = model.wallpaper, model.preferences.theme == "glass" {
                            GeometryReader { geometry in
                                Image(uiImage: wallpaper).resizable().scaledToFill().frame(width: geometry.size.width,height: geometry.size.height).clipped()
                                    .overlay(Color(uiColor: .systemBackground).opacity(0.65))
                            }.ignoresSafeArea().accessibilityHidden(true)
                        }
                    }
            }
        }
        .disabled(model.busy)
        .overlay { if model.busy { ProgressView().padding(24).background(.regularMaterial,in: RoundedRectangle(cornerRadius: 18)) } }
        .alert(model.error != nil ? "操作未完成" : "学迹",isPresented: Binding(get: { model.error != nil || model.notice != nil },set: { if !$0 { model.error = nil; model.notice = nil } })) {
            Button("好",role: .cancel) { model.error = nil; model.notice = nil }
        } message: { Text(model.error ?? model.notice ?? "") }
    }
}
