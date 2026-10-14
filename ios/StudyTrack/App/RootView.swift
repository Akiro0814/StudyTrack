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
                    Tab("首页",systemImage: "house",value: 0) { AppNavigation { HomeView() } }
                    Tab("科目",systemImage: "books.vertical",value: 1) { AppNavigation { SubjectsView() } }
                    Tab("成绩",systemImage: "list.bullet.rectangle",value: 2) { AppNavigation { ExamsView() } }
                    Tab("分析",systemImage: "chart.xyaxis.line",value: 3) { AppNavigation { AnalysisView() } }
                    Tab("设置",systemImage: "gearshape",value: 4) { AppNavigation { SettingsView() } }
                }.id(model.selectionRevision)
                    .background { AppCanvas() }
            }
        }
        .disabled(model.busy)
        .overlay { if model.busy { ProgressView().padding(24).background(.regularMaterial,in: RoundedRectangle(cornerRadius: 18)) } }
        .alert(model.error != nil ? "操作未完成" : "学迹",isPresented: Binding(get: { model.error != nil || model.notice != nil },set: { if !$0 { model.error = nil; model.notice = nil } })) {
            Button("好",role: .cancel) { model.error = nil; model.notice = nil }
        } message: { Text(model.error ?? model.notice ?? "") }
    }
}

private struct AppNavigation<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack { content }
            .containerBackground(for: .navigation) { AppCanvas() }
    }
}
