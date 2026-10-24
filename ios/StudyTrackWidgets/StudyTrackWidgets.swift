import SwiftUI
import WidgetKit
import AppIntents
import StudyTrackCore

struct StudySelection: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "成绩范围" }
    static var defaultQuery: StudySelectionQuery { StudySelectionQuery() }
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct StudySelectionQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StudySelection] { choices.filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [StudySelection] { choices }
    var choices: [StudySelection] { (WidgetArchive.load()?.series ?? []).map { StudySelection(id: $0.id,name: $0.subtitle + " · " + $0.title + " · " + Score.text($0.fullScore) + "分制") } }
}
struct StudyConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "学习成绩" }
    static var description: IntentDescription { IntentDescription("选择用户、学期或阶段以及科目。") }
    @Parameter(title: "成绩范围") var selection: StudySelection?
}
struct StudyEntry: TimelineEntry {
    let date: Date
    let updated: Date?
    let series: WidgetSeries?
    var selectionMissing = false
}
struct StudyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StudyEntry { StudyEntry(date: .now,updated: nil,series: nil) }
    func snapshot(for configuration: StudyConfiguration,in context: Context) async -> StudyEntry { entry(configuration) }
    func timeline(for configuration: StudyConfiguration,in context: Context) async -> Timeline<StudyEntry> { Timeline(entries: [entry(configuration)],policy: .after(.now.addingTimeInterval(1800))) }
    func entry(_ configuration: StudyConfiguration) -> StudyEntry {
        let archive = WidgetArchive.load()
        let id = configuration.selection?.id ?? archive?.defaultID
        let series = archive?.series.first { $0.id == id }
        return StudyEntry(date: .now,updated: archive?.updatedAt,series: series,selectionMissing: configuration.selection != nil && series == nil)
    }
}

struct StudyWidgetView: View {
    let entry: StudyEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if let series = entry.series,let latest = series.scores.last {
                if family == .accessoryInline {
                    Text("\(series.title) \(Score.text(latest))分").privacySensitive()
                } else if family == .accessoryCircular {
                    Gauge(value: Double(latest),in: 0...Double(max(1,series.fullScore))) { Text(series.title) } currentValueLabel: { Text("\(Int(Double(latest)/Double(max(1,series.fullScore))*100))%") }.gaugeStyle(.accessoryCircular).privacySensitive()
                } else {
                    VStack(alignment: .leading,spacing: family == .accessoryRectangular ? 3 : 9) {
                        HStack { Text(series.title).font(.headline); Spacer(); Text(Score.text(latest)).font(.headline.monospacedDigit()) }.privacySensitive()
                        if family != .accessoryRectangular { Text(series.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2).privacySensitive() }
                        Sparkline(scores: series.scores,fullScore: series.fullScore).frame(maxHeight: .infinity).privacySensitive()
                        if family == .systemMedium || family == .systemLarge {
                            HStack { Text("均分 \(series.average.map { String(format: "%.1f",$0) } ?? "—")"); Spacer(); Text("最高 \(series.maximum.map(Score.text) ?? "—")"); Spacer(); Text("优秀率 \(series.excellenceRate.map { "\($0)%" } ?? "—")") }.font(.caption2).privacySensitive()
                        }
                        if family == .systemLarge { Text("\(series.count) 次记录 · 最近 \(series.dates.last ?? "")").font(.caption).foregroundStyle(.secondary).privacySensitive() }
                        if family != .accessoryRectangular {
                            HStack {
                                if series.scores.count > 1 { let delta = latest-series.scores[series.scores.count-2]; Text("较上次 \(delta >= 0 ? "+" : "−")\(Score.text(abs(delta)))").privacySensitive() }
                                Spacer(); if let updated = entry.updated { Text(updated,style: .time) }
                            }.font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                if family == .accessoryInline {
                    Text(entry.selectionMissing ? "学迹 · 请重新选择科目" : "学迹 · 暂无成绩")
                } else if family == .accessoryCircular {
                    Image(systemName: "chart.xyaxis.line").accessibilityLabel("打开学迹记录成绩")
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "chart.xyaxis.line")
                        if let series = entry.series { Text(series.title).font(.headline).privacySensitive() }
                        Text(entry.selectionMissing ? "原成绩范围已不可用\n长按小组件重新选择" : "打开学迹，选择科目并记录成绩").font(.caption).multilineTextAlignment(.center)
                    }
                }
            }
        }.containerBackground(.background,for: .widget).widgetURL(entry.series?.deepLink ?? URL(string: "studytrack://analysis"))
    }
}
struct Sparkline: View {
    let scores: [Int64]
    let fullScore: Int64
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for (index,score) in scores.enumerated() {
                    let point = CGPoint(x: scores.count == 1 ? proxy.size.width/2 : proxy.size.width*Double(index)/Double(scores.count-1),y: proxy.size.height*(1-Double(score)/Double(max(1,fullScore))))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                if scores.count == 1 { path.addLine(to: CGPoint(x: proxy.size.width/2+1,y: proxy.size.height*(1-Double(scores[0])/Double(max(1,fullScore))))) }
            }.stroke(.tint,style: StrokeStyle(lineWidth: 2,lineCap: .round,lineJoin: .round))
        }.accessibilityLabel("最近 \(scores.count) 次成绩趋势")
    }
}
@main struct StudyTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyTrackWidget()
    }
}
struct StudyTrackWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StudyTrackGrades",intent: StudyConfiguration.self,provider: StudyProvider()) { StudyWidgetView(entry: $0) }
            .configurationDisplayName("学迹成绩趋势").description("在桌面或锁屏回看每次进步。")
            .supportedFamilies([.systemSmall,.systemMedium,.systemLarge,.accessoryRectangular,.accessoryCircular,.accessoryInline])
    }
}
