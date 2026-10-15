import SwiftUI
import PhotosUI
import StudyTrackCore

struct PersonalizationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var item: PhotosPickerItem?
    @State private var reset = false
    var body: some View {
        StudyScroll {
            VStack(alignment: .leading,spacing: 8) {
                Text("让学迹，更像你。").font(.title2.bold())
                Text("你喜欢的颜色、照片和阅读方式。").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading,spacing: 16) {
                SectionHeading(title: "内容质感")
                HStack(spacing: 12) {
                    theme("默认",subtitle: "柔和 · 高斯模糊",symbol: "rectangle",value: "simple")
                    theme("液态玻璃",subtitle: "流动 · 原生玻璃",symbol: "square.on.square",value: "glass")
                }
                if model.preferences.theme == "glass" { NavigationLink("液态玻璃材质调节") { GlassSettingsView() } }
                Picker("显示模式",selection: Binding(get: { model.preferences.displayMode },set: { value in var p = model.preferences; p.displayMode = value; Task { await model.savePreferences(p) } })) {
                    Text("亮色模式").tag("light"); Text("暗色模式").tag("dark"); Text("跟随系统").tag("system")
                }.pickerStyle(.menu).accessibilityIdentifier("appearance.mode")
            }.studySurface()
            VStack(alignment: .leading,spacing: 20) {
                SectionHeading(title: "主题色")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { colors }
                    VStack(alignment: .leading,spacing: 16) { colors }
                }
                NavigationLink("自定义主题色") { ThemeColorEditor() }
            }.studySurface()
            VStack(alignment: .leading,spacing: 16) {
                SectionHeading(title: "一张喜欢的壁纸")
                PhotosPicker(selection: $item,matching: .images) {
                    SettingsRow(title: model.wallpaper == nil ? "从照片中选择" : "更换壁纸",subtitle: "铺满学习空间，文字保持清晰",symbol: "photo.on.rectangle.angled",color: model.accent)
                }.buttonStyle(.plain).accessibilityIdentifier("appearance.wallpaper")
                if model.wallpaper != nil {
                    Divider()
                    Button("移除壁纸",role: .destructive) { var p = model.preferences; p.wallpaperAssetID = nil; Task { await model.savePreferences(p) } }
                }
            }.studySurface()
            Button("恢复默认外观",role: .destructive) { reset = true }.font(.subheadline).frame(maxWidth: .infinity,minHeight: 44)
        }.navigationTitle("个性化").navigationBarTitleDisplayMode(.inline)
            .onChange(of: item) { _,value in
                guard let value else { return }
                Task {
                    _ = await model.perform {
                        guard let data = try await value.loadTransferable(type: Data.self), let files = model.files, let store = model.store else { throw StudyError.invalid("照片未能下载，请重试。") }
                        let candidate = try await files.saveWallpaper(data)
                        let asset = try await store.addAsset(candidate)
                        var p = model.preferences; p.wallpaperAssetID = asset.id; try await store.updatePreferences(p)
                    }
                    item = nil
                }
            }
            .confirmationDialog("恢复默认外观？",isPresented: $reset,titleVisibility: .visible) {
                Button("恢复默认",role: .destructive) { var p = model.preferences; p.theme = "simple"; p.accent = "blue"; p.wallpaperAssetID = nil; p.displayMode = "system"; p.glassVariant = "regular"; p.glassTint = 0.08; p.glassBacking = 0.15; Task { await model.savePreferences(p) } }
            }
    }
    func theme(_ title: String,subtitle: String,symbol: String,value: String) -> some View {
        Button {
            var p = model.preferences; p.theme = value; Task { await model.savePreferences(p) }
        } label: {
            VStack(alignment: .leading,spacing: 12) {
                HStack { Image(systemName: symbol).font(.title2); Spacer(); if model.preferences.theme == value { Image(systemName: "checkmark.circle.fill") } }
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity,alignment: .leading)
                .background(model.preferences.theme == value ? model.accent.opacity(0.10) : Color.primary.opacity(0.03),in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(model.preferences.theme == value ? model.accent : .clear,lineWidth: 1.5) }
        }.buttonStyle(.plain).foregroundStyle(model.preferences.theme == value ? model.accent : .primary).accessibilityAddTraits(model.preferences.theme == value ? [.isSelected] : [])
    }
    var colors: some View {
        ForEach(["blue","green","orange","purple"],id: \.self) { key in
            let color: Color = key == "green" ? Color(red: 0.10,green: 0.56,blue: 0.44) : key == "orange" ? Color(red: 0.88,green: 0.32,blue: 0.24) : key == "purple" ? Color(red: 0.61,green: 0.36,blue: 0.82) : Color(red: 0.29,green: 0.40,blue: 0.91)
            Button {
                var p = model.preferences; p.accent = key; Task { await model.savePreferences(p) }
            } label: {
                ZStack { Circle().fill(color); if model.preferences.accent == key { Image(systemName: "checkmark").font(.headline).foregroundStyle(.white) } }.frame(width: 48,height: 48)
            }.buttonStyle(.plain).accessibilityLabel(["blue":"鸢尾蓝","green":"松石绿","orange":"珊瑚红","purple":"暮光紫"][key] ?? key).accessibilityAddTraits(model.preferences.accent == key ? [.isSelected] : [])
        }
    }
}

struct ProfileAppearanceView: View {
    @Environment(AppModel.self) private var model
    @State private var item: PhotosPickerItem?
    @State private var name = ""
    @State private var failure: String?
    @State private var remove = false
    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    AvatarView(size: 100)
                    PhotosPicker(model.avatar == nil ? "上传你的头像" : "更换头像",selection: $item,matching: .images).accessibilityIdentifier("profile.photo")
                    Text("在首页，遇见更熟悉的自己。").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical,20)
                if model.avatar != nil { Button("移除头像",role: .destructive) { remove = true } }
            }
            Section("怎么称呼你") { TextField("姓名或昵称",text: $name).textContentType(.nickname).accessibilityIdentifier("profile.name"); InlineError(message: failure) }
            Section { Text("每个用户档案拥有独立头像。头像保存在本机，也会随完整备份或 iCloud 备份保存。").font(.caption).foregroundStyle(.secondary) }
        }.studyCanvas().navigationTitle("个人资料").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    guard let user = model.currentUser else { return }
                    Task {
                        if await model.perform(onError: { failure = $0 }, { try await model.store?.renameUser(id: user.id,name: name) }) { model.notice = "称呼已更新。" }
                    }
                }.disabled(normalize(name).isEmpty || name == model.currentUser?.name)
            } }
            .onAppear { name = model.currentUser?.name ?? "" }
            .onChange(of: item) { _,value in
                guard let value, let userID = model.currentUser?.id else { return }
                Task {
                    _ = await model.perform(onError: { failure = $0 }) {
                        guard let data = try await value.loadTransferable(type: Data.self), let files = model.files, let store = model.store else { throw StudyError.invalid("照片未能下载，请重试。") }
                        let candidate = try await files.saveAvatar(data)
                        let asset = try await store.addAsset(candidate)
                        guard model.currentUser?.id == userID else { throw StudyError.scopeChanged }
                        var p = model.preferences; p.setAvatarAssetID(asset.id,for: userID); try await store.updatePreferences(p)
                    }; item = nil
                }
            }
            .confirmationDialog("移除当前头像？",isPresented: $remove,titleVisibility: .visible) {
                Button("移除头像",role: .destructive) { if let id = model.currentUser?.id { var p = model.preferences; p.setAvatarAssetID(nil,for: id); Task { await model.savePreferences(p) } } }
            }
    }
}
