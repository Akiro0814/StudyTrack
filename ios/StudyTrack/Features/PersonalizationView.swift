import SwiftUI
import PhotosUI
import StudyTrackCore

struct PersonalizationView: View {
    @Environment(AppModel.self) private var model
    @State private var item: PhotosPickerItem?
    @State private var wallpaper: UIImage?
    @State private var reset = false
    var body: some View {
        Form {
            Section("主题") {
                Picker("内容主题",selection: Binding(get: { model.preferences.theme },set: { value in var p = model.preferences; p.theme = value; Task { await model.savePreferences(p) } })) {
                    Text("简洁").tag("simple"); Text("原生液态玻璃").tag("glass")
                }
                Picker("强调色",selection: Binding(get: { model.preferences.accent },set: { value in var p = model.preferences; p.accent = value; Task { await model.savePreferences(p) } })) {
                    Text("蓝色").tag("blue"); Text("绿色").tag("green"); Text("橙色").tag("orange"); Text("紫色").tag("purple")
                }
            }
            Section("壁纸") {
                PhotosPicker("选择照片",selection: $item,matching: .images)
                Button("清除壁纸",role: .destructive) { var p = model.preferences; p.wallpaperAssetID = nil; Task { await model.savePreferences(p); wallpaper = nil } }
                Text("壁纸用于玻璃主题背景；简洁主题下暂时停用，深浅色跟随系统。").font(.caption).foregroundStyle(.secondary)
            }
            Section("预览") {
                ZStack {
                    if let wallpaper, model.preferences.theme == "glass" { Image(uiImage: wallpaper).resizable().scaledToFill().frame(height: 220).clipped() }
                    else { Color(uiColor: .secondarySystemGroupedBackground) }
                    VStack(spacing: 20) { Text("下一次，也值得记录。").font(.headline).padding().background(.background,in: RoundedRectangle(cornerRadius: 12)); AddExamButton {} }
                }.frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Button("恢复默认外观",role: .destructive) { reset = true }
        }.navigationTitle("个性化")
            .onChange(of: item) { _, value in
                guard let value else { return }
                Task {
                    _ = await model.perform {
                        guard let data = try await value.loadTransferable(type: Data.self), let files = model.files, let store = model.store else { throw StudyError.invalid("照片未能下载，请重试。") }
                        let candidate = try await files.saveWallpaper(data); let asset = try await store.addAsset(candidate)
                        var p = model.preferences; p.wallpaperAssetID = asset.id; try await store.updatePreferences(p)
                    }
                    await loadWallpaper()
                }
            }
            .task { await loadWallpaper() }
            .confirmationDialog("恢复默认外观？",isPresented: $reset,titleVisibility: .visible) { Button("恢复默认",role: .destructive) { var p = model.preferences; p.theme = "simple"; p.accent = "blue"; p.wallpaperAssetID = nil; Task { await model.savePreferences(p); wallpaper = nil } } }
    }
    func loadWallpaper() async {
        do {
            guard let id = model.preferences.wallpaperAssetID, let snapshot = try await model.store?.snapshot(), let asset = snapshot.assets.first(where: { $0.id == id }), let data = try await model.files?.wallpaper(asset) else { wallpaper = nil; return }
            wallpaper = UIImage(data: data)
        } catch { model.error = model.friendly(error) }
    }
}
