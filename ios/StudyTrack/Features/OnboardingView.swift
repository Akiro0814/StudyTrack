import SwiftUI

struct OnboardingView: View {
    @State private var showingProfile = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            Group {
                if showingProfile { ProfileSetupForm(onboarding: true).transition(.opacity.combined(with: .scale(scale: 0.96))) }
                else { SoftwareGuide { withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.55,dampingFraction: 0.9)) { showingProfile = true } }.transition(.opacity) }
            }
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
        ("person.crop.circle","从你的学习档案开始","无需注册，设置称呼与头像，选择小学、初中、高中或大学和当前学期。多用户模式可为家人分别记录。","用户之间独立保存；关闭多用户模式不会删除其他档案。"),
        ("books.vertical","给每次努力一个归属","先创建科目并设置满分。开启下一学期可继承同阶段科目，历史成绩仍留在原学期。","学习阶段与学期分别管理，避免混淆不同年级的记录。"),
        ("pencil.and.list.clipboard","一科，或整场考试","单条记录分数、名称、日期和考试类型；批量录入可一次保存多科。班排、年排、区排和反思都是可选项。","填写中会保存草稿；所有行通过检查后才一起保存。"),
        ("list.bullet.rectangle","让记录随时可找","首页查看最近成绩和各科概览，成绩明细可搜索考试名称。轻点编辑、左滑删除，误删后可立即撤销。","不同满分独立统计，空排名不会被当作最后一名。"),
        ("chart.xyaxis.line","看见每一步变化","查看分数与三种排名趋势、均分、最高分和优秀率。同满分多科可在一张曲线上比较，也可汇总整个学习阶段。","轻点图表查看每场考试；同一天的多次考试也各有位置。"),
        ("tablecells","让旧记录也加入旅程","通过 Excel 导入或导出成绩。导入前查看预览和行号提示，确认科目、日期、分数、满分与分类再保存。","可先导出模板；月考、期中、期末和其他是四种考试分类。"),
        ("icloud.and.arrow.up","让记录安心留存","完整备份保存全部用户、学期、成绩、头像、壁纸和设置。可存入 iCloud Drive 或导出文件，恢复前先校验和预览。","恢复会替换本机数据并保存恢复快照；文件保存与云端传输状态分别显示。"),
        ("paintpalette","把学迹变成你的样子","设置主题色、浅色或深色外观、玻璃质感与壁纸。添加桌面或锁屏成绩小组件，选择档案、学期或阶段和科目。","在设置中可随时回看本引导。数据默认留在本机，备份文件未加密，请妥善保管。")
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
                                .scaleEffect(reduceMotion || index == page ? 1 : 0.9)
                                .animation(reduceMotion ? nil : .spring(response: 0.5,dampingFraction: 0.85),value: page)
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
                .animation(reduceMotion ? nil : .spring(response: 0.4,dampingFraction: 0.85),value: page)
            HStack {
                Button("上一步") { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { page = max(0,page-1) } }.disabled(page == 0)
                Spacer()
                Text("\(page+1) / \(pages.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal,24)
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
