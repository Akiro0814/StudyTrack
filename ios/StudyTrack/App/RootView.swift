import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab = 0
    @State private var pendingWidgetURL: URL?
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
                    Tab("成绩分析",systemImage: "chart.xyaxis.line",value: 2) { AppNavigation { AnalysisView() } }
                    Tab("设置",systemImage: "gearshape",value: 4) { AppNavigation { SettingsView() } }
                }.id(model.selectionRevision)
                    .background { AppCanvas() }
            }
        }
        .disabled(model.busy)
        .onOpenURL { url in
            if model.ready { Task { await model.openWidget(url) } }
            else { pendingWidgetURL = url }
        }
        .onChange(of: model.ready) { _,ready in if ready,let url = pendingWidgetURL { pendingWidgetURL = nil; Task { await model.openWidget(url) } } }
        .onChange(of: model.analysisRoute) { _,value in if value != nil { selectedTab = 2 } }
        .task(id: model.recentlyDeleted?.id) {
            guard let id = model.recentlyDeleted?.id else { return }
            do { try await Task.sleep(for: .seconds(8)); try Task.checkCancellation() } catch { return }
            if model.recentlyDeleted?.id == id { model.recentlyDeleted = nil }
        }
        .preferredColorScheme(model.preferences.displayMode == "light" ? .light : model.preferences.displayMode == "dark" ? .dark : nil)
        .safeAreaInset(edge: .bottom) {
            if model.recentlyDeleted != nil {
                HStack { Text("已删除成绩"); Spacer(); Button("撤销") { Task { await model.undoDeletion() } }; Button("关闭",systemImage: "xmark") { model.recentlyDeleted = nil }.labelStyle(.iconOnly) }
                    .font(.subheadline).padding().background(.regularMaterial,in: Capsule()).padding(.horizontal)
            }
        }
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
