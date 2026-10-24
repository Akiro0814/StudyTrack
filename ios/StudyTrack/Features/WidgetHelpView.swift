import SwiftUI
import StudyTrackCore

struct WidgetHelpView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        List {
            Section("添加到桌面") {
                Text("长按桌面空白处，选择编辑 → 添加小组件，搜索“学迹”。提供小、中、大三种尺寸。")
                Text("长按已添加的小组件，选择编辑小组件，可指定用户、学期或学习阶段与科目。未指定时显示当前学期最近有成绩的科目。")
            }
            Section("添加到锁屏") {
                Text("长按锁屏并选择自定，在小组件区域添加学迹。支持圆形、矩形和单行成绩。")
                Text("解锁后打开一次学迹即可刷新共享数据；系统决定后续刷新时机，添加成绩后也会主动请求刷新。")
            }
            Section("刷新与排查") {
                if let message = model.widgetStatus { Label(message,systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                else { Label("共享数据已准备",systemImage: "checkmark.circle").foregroundStyle(.secondary) }
                Button("立即刷新小组件") { Task { await model.publishWidgetsNow() } }
                Text("若在自签安装后找不到组件，请确认安装工具保留了 StudyTrackWidgets.appex，并为应用及扩展签入相同的 App Group。文件备份不依赖此权限。")
            }
        }.studyCanvas().navigationTitle("小组件").task { await model.publishWidgetsNow() }
    }
}
