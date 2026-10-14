import SwiftUI
import StudyTrackCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var recording: RecordIntent?
    @State private var editing: Exam?
    var body: some View {
        StudyScroll {
            HStack(spacing: 16) {
                NavigationLink { ProfileAppearanceView() } label: { AvatarView(size: 64) }
                    .buttonStyle(.plain).accessibilityLabel("编辑头像与个人资料").accessibilityIdentifier("home.avatar")
                VStack(alignment: .leading,spacing: 6) {
                    Text("今天，也向前一点。").font(.subheadline).foregroundStyle(.secondary)
                    Text(model.currentUser?.name ?? "同学").font(.largeTitle.bold()).lineLimit(2)
                }
                Spacer(minLength: 0)
            }.padding(.vertical,8)
            VStack(alignment: .leading,spacing: 20) {
                HStack {
                    Label("学习进行时",systemImage: "sparkle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    NavigationLink { SemestersView() } label: {
                        HStack(spacing: 4) { Text(model.currentSemester?.name ?? "学期"); Image(systemName: "chevron.down").font(.caption2) }.font(.caption.weight(.medium))
                    }.accessibilityLabel("切换学期，\(model.currentSemester?.name ?? "")")
                }
                if let latest = model.home.rows.first, let subject = model.subjects.first(where: { $0.id == latest.subjectID }) {
                    Button { editing = latest } label: {
                        HStack(alignment: .center,spacing: 16) {
                            VStack(alignment: .leading,spacing: 4) {
                                Text("最近一次 · \(subject.name)").font(.subheadline).foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline,spacing: 6) {
                                    Text(Score.text(latest.score)).font(.system(.largeTitle,design: .rounded,weight: .bold)).contentTransition(.numericText())
                                    Text("/ \(Score.text(subject.fullScore))").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("\(latest.name.isEmpty ? latest.type.label : latest.name) · \(latest.date.description)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            ZStack {
                                Circle().stroke(model.accent.opacity(0.12),lineWidth: 7)
                                Circle().trim(from: 0,to: min(1,Double(latest.score)/Double(max(1,subject.fullScore))))
                                    .stroke(model.accent.gradient,style: StrokeStyle(lineWidth: 7,lineCap: .round)).rotationEffect(.degrees(-90))
                                Text(Grade.classify(score: latest.score,full: subject.fullScore).rawValue).font(.title2.weight(.semibold))
                            }.frame(width: 64,height: 64).accessibilityHidden(true)
                        }.foregroundStyle(.primary).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                } else {
                    Text("你的进步，\n从第一次记录开始。").font(.system(.title,design: .rounded,weight: .bold)).fixedSize(horizontal: false,vertical: true)
                    Text("留下分数，也留下努力的轨迹。").font(.subheadline).foregroundStyle(.secondary)
                }
                Button { recording = .single } label: {
                    Label("添加成绩",systemImage: "plus").font(.headline).frame(maxWidth: .infinity).padding(.vertical,6)
                }.buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule).accessibilityIdentifier("home.add")
                Button { recording = .batch } label: {
                    Label("一次考试，多科录入",systemImage: "square.stack.3d.up").font(.subheadline).frame(maxWidth: .infinity,minHeight: 36)
                }
            }.studySurface()
            VStack(alignment: .leading,spacing: 16) {
                SectionHeading(title: "本学期",detail: "\(model.subjects.count) 科 · \(model.home.total) 次记录")
                VStack(alignment: .leading,spacing: 14) { SummaryView(summary: model.home.summary) }.studySurface()
            }
            VStack(alignment: .leading,spacing: 16) {
                SectionHeading(title: "最近的足迹",detail: "轻点编辑")
                if model.home.rows.isEmpty {
                    EmptyStudyView(title: "把努力留在这里",message: "每场考试都是一个新的起点。",symbol: "pencil.and.list.clipboard",actionTitle: "记录第一场考试") { recording = .single }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.home.rows.enumerated()),id: \.element.id) { index,exam in
                            if index > 0 { Divider().padding(.vertical,12) }
                            Button { editing = exam } label: { ExamRowView(exam: exam,subjects: model.subjects).foregroundStyle(.primary) }.buttonStyle(.plain)
                        }
                    }.studySurface()
                }
            }
        }.navigationTitle("学迹").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("设置") } }
            .refreshable { do { try await model.reload() } catch { model.error = model.friendly(error) } }
            .recordEntry($recording)
            .sheet(item: $editing) { exam in if let scope = model.scope { ExamEditorView(scope: scope,existing: exam) } }
    }
}
