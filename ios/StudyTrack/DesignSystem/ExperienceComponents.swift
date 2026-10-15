import SwiftUI
import StudyTrackCore

private struct StudySurfaceSchemeKey: EnvironmentKey { static let defaultValue: ColorScheme = .light }
extension EnvironmentValues {
    var studySurfaceScheme: ColorScheme {
        get { self[StudySurfaceSchemeKey.self] }
        set { self[StudySurfaceSchemeKey.self] = newValue }
    }
}

struct AppCanvas: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                if let image = model.wallpaper {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: proxy.size.width,height: proxy.size.height).clipped()
                    (scheme == .dark ? Color.black : Color.white).opacity(scheme == .dark ? 0.24 : 0.12)
                } else {
                    LinearGradient(colors: [model.accent.opacity(scheme == .dark ? 0.18 : 0.09),.clear],startPoint: .topLeading,endPoint: .center)
                    RadialGradient(colors: [Color.orange.opacity(0.06),.clear],center: .trailing,startRadius: 0,endRadius: 450)
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct StudyScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 28) { content }
                .frame(maxWidth: 720).padding(.horizontal,20).padding(.top,12).padding(.bottom,28)
                .frame(maxWidth: .infinity)
        }.background { AppCanvas() }.scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft,for: .top)
            .environment(\.colorScheme,model.wallpaper == nil ? scheme : (model.wallpaperUsesLightText ? .dark : .light))
            .environment(\.studySurfaceScheme,scheme)
    }
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
}

struct StudySurface: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) private var solid
    @Environment(\.studySurfaceScheme) private var surfaceScheme
    func body(content: Content) -> some View {
        content.padding(20).frame(maxWidth: .infinity,alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: 26,style: .continuous)
                if !solid && model.preferences.theme == "glass" {
                    shape.fill(Color(uiColor: .systemBackground).opacity(model.preferences.glassBacking))
                        .glassEffect((model.preferences.glassVariant == "clear" ? Glass.clear : Glass.regular).tint(model.accent.opacity(model.preferences.glassTint)),in: shape)
                } else if !solid {
                    shape.fill(.regularMaterial)
                } else { shape.fill(Color(uiColor: .secondarySystemGroupedBackground)) }
            }
            .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.04),lineWidth: 1) }
            .environment(\.colorScheme,surfaceScheme)
    }
}
extension View {
    func studySurface() -> some View { modifier(StudySurface()) }
    func studyCanvas() -> some View { scrollContentBackground(.hidden).background { AppCanvas() }.scrollDismissesKeyboard(.interactively).scrollEdgeEffectStyle(.soft,for: .top) }
}

struct BrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        Image("BrandMark").resizable().scaledToFit().frame(width: size,height: size)
            .clipShape(RoundedRectangle(cornerRadius: size*0.23,style: .continuous))
            .accessibilityHidden(true)
    }
}
struct AvatarView: View {
    @Environment(AppModel.self) private var model
    var size: CGFloat = 60
    var body: some View {
        ZStack {
            Circle().fill(model.accent.gradient)
            if let image = model.avatar { Image(uiImage: image).resizable().scaledToFill() }
            else { Text(String((model.currentUser?.name ?? "学").prefix(1))).font(.system(size: size*0.40,weight: .semibold,design: .rounded)).foregroundStyle(.white) }
        }.frame(width: size,height: size).clipShape(Circle())
            .overlay { Circle().strokeBorder(.white.opacity(0.35),lineWidth: 2) }.accessibilityHidden(true)
    }
}
struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold()); Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.accessibilityAddTraits(.isHeader)
    }
}
struct EmptyStudyView: View {
    let title: String
    let message: String
    let symbol: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 32,weight: .light)).foregroundStyle(.tint)
                .frame(width: 72,height: 72).background(.tint.opacity(0.10),in: RoundedRectangle(cornerRadius: 24))
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(actionTitle,action: action).buttonStyle(StudyPrimaryButtonStyle()).controlSize(.large)
        }.frame(maxWidth: .infinity).padding(.vertical,24).studySurface()
    }
}
struct SubjectFilter: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: String
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("全部科目",id: "")
                ForEach(model.subjects) { chip($0.name,id: $0.id) }
            }.padding(.vertical,2)
        }.scrollIndicators(.hidden).accessibilityLabel("按科目筛选").sensoryFeedback(.selection,trigger: selection)
    }
    func chip(_ name: String,id: String) -> some View {
        Button { selection = id } label: {
            Text(name).font(.subheadline.weight(.medium)).padding(.horizontal,16).frame(minHeight: 44)
                .background(selection == id ? model.accent : Color(uiColor: .secondarySystemGroupedBackground),in: Capsule())
                .foregroundStyle(selection == id ? Color.white : Color.primary)
        }.buttonStyle(.plain).accessibilityAddTraits(selection == id ? [.isSelected] : [])
    }
}
struct SettingsRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var color: Color = .blue
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(color)
                .frame(width: 42,height: 42).background(color.opacity(0.12),in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading,spacing: 4) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.padding(.vertical,8).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}

enum RecordIntent: String, Identifiable { case single, batch; var id: String { rawValue } }
private enum RecordRoute: String, Identifiable { case subject, single, batch; var id: String { rawValue } }
private struct RecordEntry: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var intent: RecordIntent?
    @State private var route: RecordRoute?
    @State private var needsSubject = false
    @State private var created = false
    func body(content: Content) -> some View {
        content.onChange(of: intent) { _, value in
            guard let value else { return }
            if model.subjects.isEmpty { needsSubject = true }
            else { route = value == .batch ? .batch : .single }
        }
        .alert("先添加一个科目",isPresented: $needsSubject) {
            Button("添加科目") { created = false; route = .subject }
            Button("稍后再说",role: .cancel) { intent = nil }
        } message: { Text("给这条成绩一个归属。创建科目并设置满分后，会继续刚才的录入。") }
        .sheet(item: $route,onDismiss: {
            if created {
                created = false
                route = intent == .batch ? .batch : .single
            } else { intent = nil }
        }) { destination in
            if let scope = model.scope {
                switch destination {
                case .subject: SubjectEditorView(scope: scope,subject: nil,onSaved: { created = true })
                case .single: ExamEditorView(scope: scope,existing: nil)
                case .batch: BatchEditorView(scope: scope)
                }
            }
        }
    }
}
extension View {
    func recordEntry(_ intent: Binding<RecordIntent?>) -> some View { modifier(RecordEntry(intent: intent)) }
}
