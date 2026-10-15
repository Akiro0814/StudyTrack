import SwiftUI

struct OnboardingView: View {
    @State private var showingProfile = false
    var body: some View {
        NavigationStack {
            if showingProfile { ProfileSetupForm(onboarding: true) }
            else { SoftwareGuide { showingProfile = true } }
        }
            .containerBackground(for: .navigation) { AppCanvas() }
    }
}

struct SoftwareGuide: View {
    var onFinish: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    private let pages: [(symbol: String,title: String,detail: String,hint: String)] = [
        ("pencil.and.list.clipboard","留下每一次努力","先设置学习档案与学期，再添加科目和满分。一次考试，也能一起录入多科成绩。","最近的足迹：轻点编辑，左滑删除；误删可以撤销。"),
        ("chart.xyaxis.line","看见自己的进步","在成绩分析中查看分科趋势。同满分科目可以放在一起比较，也能汇总整个学习阶段。","开启下一学期会继承科目，成绩各自保存。"),
        ("icloud.and.arrow.up","让记录安心留存","成绩默认保存在本机。在数据与备份中导入 Excel，或将完整备份保存到 iCloud Drive。","恢复前先查看预览；建议定期备份，也可添加桌面和锁屏小组件。")
    ]
    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $page) {
                ForEach(pages.indices,id: \.self) { index in
                    ScrollView {
                        VStack(alignment: .leading,spacing: 28) {
                            HStack { BrandMark(size: 48); Spacer(); Text("\(index+1) / \(pages.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                            Image(systemName: pages[index].symbol).font(.system(size: 64,weight: .light))
                                .foregroundStyle(model.accent.gradient).frame(maxWidth: .infinity).padding(.vertical,30)
                                .accessibilityHidden(true)
                            Text(pages[index].title).font(.largeTitle.bold()).fixedSize(horizontal: false,vertical: true)
                            Text(pages[index].detail).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
                            Label(pages[index].hint,systemImage: "lightbulb").font(.subheadline).fixedSize(horizontal: false,vertical: true).studySurface()
                        }.frame(maxWidth: 600).padding(24).frame(maxWidth: .infinity)
                    }.scrollEdgeEffectStyle(.soft,for: .top).tag(index)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 8) {
                ForEach(pages.indices,id: \.self) { index in
                    Capsule().fill(index == page ? model.accent : Color.secondary.opacity(0.25)).frame(width: index == page ? 24 : 8,height: 6)
                }
            }.accessibilityLabel("引导，第 \(page+1) 页，共 \(pages.count) 页")
            Button {
                if page == pages.count-1 { onFinish() }
                else { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { page += 1 } }
            } label: {
                HStack { Text(page == pages.count-1 ? "开始使用" : "下一步"); Spacer(); Image(systemName: "arrow.right") }.font(.headline).padding(.vertical,10)
            }.buttonStyle(StudyPrimaryButtonStyle()).padding(.horizontal,24).padding(.bottom,16).accessibilityIdentifier("guide.next")
        }.background { AppCanvas() }.navigationTitle("欢迎来到学迹").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("跳过",action: onFinish).accessibilityIdentifier("guide.skip") } }
    }
}
