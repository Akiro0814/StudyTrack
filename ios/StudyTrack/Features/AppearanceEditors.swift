import SwiftUI
import StudyTrackCore

struct GlassSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var variant = "regular"
    @State private var tint = 0.08
    @State private var backing = 0.15
    var body: some View {
        StudyScroll {
            VStack(alignment: .leading,spacing: 12) { Text("让内容浮在光里。").font(.title2.bold()); Text("材质预览").foregroundStyle(.secondary); Text("每一步成长，都清晰可见。").font(.headline) }.studySurface()
            VStack(alignment: .leading,spacing: 18) {
                Picker("玻璃变体",selection: $variant) { Text("常规").tag("regular"); Text("清透").tag("clear") }.pickerStyle(.segmented)
                Text("主题染色强度"); Slider(value: $tint,in: 0...0.5)
                Text("辅助底色强度"); Slider(value: $backing,in: 0...0.8)
                Button("恢复默认材质") { variant = "regular"; tint = 0.08; backing = 0.15 }
            }.studySurface()
        }.navigationTitle("液态玻璃材质")
            .onAppear { variant = model.preferences.glassVariant; tint = model.preferences.glassTint; backing = model.preferences.glassBacking }
            .task(id: "\(variant)|\(tint)|\(backing)") {
                do { try await Task.sleep(for: .milliseconds(180)); try Task.checkCancellation() } catch { return }
                var p = model.preferences; p.glassVariant = variant; p.glassTint = tint; p.glassBacking = backing
                await model.savePreferences(p)
            }
    }
}

struct ThemeColorEditor: View {
    @Environment(AppModel.self) private var model
    @State private var color = Color.blue
    @State private var hex = "#4A66E8"
    @State private var red = "74"
    @State private var green = "102"
    @State private var blue = "232"
    @State private var failure: String?
    @State private var hue = 0.64
    @State private var saturation = 0.68
    @State private var brightness = 0.91
    @State private var syncing = false
    var body: some View {
        Form {
            Section("颜色预览") { ColorPicker("主题色",selection: $color,supportsOpacity: false); RoundedRectangle(cornerRadius: 20).fill(color).frame(height: 84).overlay { Text("学迹 StudyTrack").foregroundStyle(rgb.usesDarkText ? .black : .white).font(.headline) } }
            Section("色彩滑块") {
                Text("色相"); Slider(value: $hue,in: 0...1).onChange(of: hue) { _,_ in applyHSB() }
                Text("饱和度"); Slider(value: $saturation,in: 0...1).onChange(of: saturation) { _,_ in applyHSB() }
                Text("亮度"); Slider(value: $brightness,in: 0...1).onChange(of: brightness) { _,_ in applyHSB() }
            }
            Section("RGB · 0–255") {
                LabeledContent("R") { TextField("0–255",text: $red).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                LabeledContent("G") { TextField("0–255",text: $green).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                LabeledContent("B") { TextField("0–255",text: $blue).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing) }
                Button("应用 RGB") {
                    guard let r = Int(red),let g = Int(green),let b = Int(blue),[r,g,b].allSatisfy({ (0...255).contains($0) }) else { failure = "RGB 每项须为 0–255 的整数。"; return }
                    sync(RGBColor(red: r,green: g,blue: b))
                }
            }
            Section("十六进制") {
                TextField("#RRGGBB",text: $hex).textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("应用十六进制") { guard let value = RGBColor.parse(normalize(hex)) else { failure = "请输入六位十六进制颜色，例如 #4A66E8。"; return }; sync(value) }
                InlineError(message: failure)
            }
        }.studyCanvas().navigationTitle("自定义主题色")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("保存") { var p = model.preferences; p.accent = rgb.hex; Task { await model.savePreferences(p); model.notice = "主题色已保存。" } } } }
            .onAppear { color = model.accent; sync(rgb) }
            .onChange(of: color) { _,_ in if !syncing { sync(rgb) } }
    }
    var rgb: RGBColor {
        var r: CGFloat = 0,g: CGFloat = 0,b: CGFloat = 0,a: CGFloat = 0
        UIColor(color).getRed(&r,green: &g,blue: &b,alpha: &a)
        return RGBColor(red: Int((r*255).rounded()),green: Int((g*255).rounded()),blue: Int((b*255).rounded()))
    }
    func applyHSB() { if !syncing { color = Color(hue: hue,saturation: saturation,brightness: brightness) } }
    func sync(_ value: RGBColor) {
        syncing = true; defer { syncing = false }
        color = Color(red: Double(value.red)/255,green: Double(value.green)/255,blue: Double(value.blue)/255)
        hex = value.hex; red = String(value.red); green = String(value.green); blue = String(value.blue); failure = nil
        var h: CGFloat = 0,s: CGFloat = 0,b: CGFloat = 0,a: CGFloat = 0
        UIColor(color).getHue(&h,saturation: &s,brightness: &b,alpha: &a)
        hue = h; saturation = s; brightness = b
    }
}
