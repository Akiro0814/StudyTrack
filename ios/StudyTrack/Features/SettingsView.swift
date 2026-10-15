import SwiftUI
import StudyTrackCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var guide = false
    var body: some View {
        StudyScroll {
            VStack(spacing: 12) {
                BrandMark(size: 80)
                Text("学迹").font(.system(.largeTitle,design: .rounded,weight: .bold))
                Text("StudyTrack").font(.subheadline.weight(.medium)).tracking(2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
                Text("留住努力的轨迹。").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical,20).accessibilityIdentifier("settings.brand")
            NavigationLink { ProfileAppearanceView() } label: {
                HStack(spacing: 16) {
                    AvatarView(size: 56)
                    VStack(alignment: .leading,spacing: 6) { Text(model.currentUser?.name ?? "学习档案").font(.title3.bold()).foregroundStyle(.primary); Text("编辑头像与称呼").font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }.studySurface()
            }.buttonStyle(.plain)
            VStack(alignment: .leading,spacing: 4) {
                SectionHeading(title: "我的学习空间").padding(.bottom,10)
                NavigationLink { PersonalizationView() } label: { SettingsRow(title: "个性化",subtitle: "壁纸、颜色与内容质感",symbol: "paintpalette.fill",color: .purple) }.accessibilityIdentifier("settings.appearance")
                Divider().padding(.leading,56)
                NavigationLink { ProfilesView() } label: { SettingsRow(title: "用户档案",subtitle: "切换、创建和管理学习者",symbol: "person.2.fill",color: .orange) }
                Divider().padding(.leading,56)
                NavigationLink { LearningStagesView() } label: { SettingsRow(title: "学习阶段",subtitle: model.currentStage?.label ?? "归类历史学期",symbol: "graduationcap",color: .teal) }.accessibilityIdentifier("settings.stages")
                Divider().padding(.leading,56)
                NavigationLink { SemestersView() } label: { SettingsRow(title: "切换学期",subtitle: model.currentSemester?.name ?? "当前阶段的学期",symbol: "calendar",color: .green) }.accessibilityIdentifier("settings.semesters")
            }.buttonStyle(.plain).studySurface()
            VStack(alignment: .leading,spacing: 4) {
                SectionHeading(title: "安心记录").padding(.bottom,10)
                NavigationLink { DataTransferView() } label: { SettingsRow(title: "数据与备份",subtitle: "Excel 交换、完整备份与恢复",symbol: "externaldrive.fill",color: model.accent) }.accessibilityIdentifier("settings.data")
                Divider().padding(.leading,56)
                NavigationLink { AboutView() } label: { SettingsRow(title: "关于学迹",subtitle: "隐私、支持与开源许可",symbol: "info.circle.fill",color: .secondary) }
                Divider().padding(.leading,56)
                Button { guide = true } label: { SettingsRow(title: "使用引导",subtitle: "回顾记录、分析与备份",symbol: "sparkles",color: .orange) }
            }.buttonStyle(.plain).studySurface()
            VStack(spacing: 8) {
                Label("只属于你的本地学习空间",systemImage: "lock.shield").font(.caption)
                Text(AppVersion.text).font(.caption2)
                Text("作者 L1angK1NG").font(.caption)
                Link("GitHub · L1angK1NG",destination: URL(string: "https://github.com/L1angK1NG")!)
                Link("ljb110814@163.com",destination: URL(string: "mailto:ljb110814@163.com")!)
            }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical,8)
        }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $guide) { NavigationStack { SoftwareGuide { guide = false } } }
    }
}

struct ProfilesView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var semester = ""
    @State private var adding = false
    @State private var renaming: User?
    @State private var deleting: User?
    @State private var confirmDelete = false
    @State private var confirmRename = false
    @State private var deleteDescription = ""
    var body: some View {
        List {
            Section {
                Toggle("多用户模式",isOn: Binding(get: { model.preferences.multiUserEnabled },set: { v in var p = model.preferences; p.multiUserEnabled = v; Task { await model.savePreferences(p) } }))
            } footer: { Text("关闭后仍保留已有档案，可重新开启。") }
            ForEach(model.users) { user in
                Button {
                    guard model.preferences.multiUserEnabled || user.id == model.preferences.currentUserID else { model.notice = "先开启上方的多用户模式，即可切换学习档案。"; return }
                    Task {
                        do { if let term = try await model.store?.semesters(userID: user.id).first { await model.switchScope(StudyScope(userID: user.id,semesterID: term.id)) } }
                        catch { model.error = model.friendly(error) }
                    }
                } label: {
                    HStack { VStack(alignment: .leading,spacing: 6) { Text(user.name); Text(user.id == model.preferences.currentUserID ? "正在使用" : "轻点切换学习档案").font(.caption).foregroundStyle(.secondary) }; Spacer(); if user.id == model.preferences.currentUserID { Image(systemName: "checkmark.circle.fill") } }.padding(.vertical,6)
                }.swipeActions {
                    Button("删除",role: .destructive) {
                        Task {
                            do {
                                guard let counts = try await model.store?.userDataCounts(id: user.id) else { return }
                                deleteDescription = "将删除 \(counts[0]) 个学期、\(counts[1]) 个科目和 \(counts[2]) 条成绩。"; deleting = user; confirmDelete = true
                            } catch { model.error = model.friendly(error) }
                        }
                    }
                    Button("重命名") { name = user.name; renaming = user; confirmRename = true }.tint(.blue)
                }
            }
        }.studyCanvas().navigationTitle("用户管理").navigationBarTitleDisplayMode(.inline)
            .toolbar { if model.preferences.multiUserEnabled { Button("添加用户",systemImage: "plus") { adding = true } } }
            .sheet(isPresented: $adding) { NavigationStack { ProfileSetupForm().toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { adding = false } } } } }
            .alert("重命名用户",isPresented: $confirmRename) {
                TextField("姓名",text: $name)
                Button("保存") { if let user = renaming { let newName = name; Task { _ = await model.perform { try await model.store?.renameUser(id: user.id,name: newName) } } } }
                Button("取消",role: .cancel) { renaming = nil }
            }
            .confirmationDialog("删除“\(deleting?.name ?? "")”？\n\(deleteDescription)",isPresented: $confirmDelete,titleVisibility: .visible) {
                Button("删除用户及全部数据",role: .destructive) { if let user = deleting { Task { _ = await model.perform { try await model.store?.deleteUser(id: user.id); model.selectionRevision += 1 } } } }
            }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section { HStack(spacing: 16) { BrandMark(size: 64); VStack(alignment: .leading,spacing: 6) { Text("学迹 StudyTrack").font(.title2.bold()); Text(AppVersion.text).font(.caption).foregroundStyle(.secondary) } }.padding(.vertical,12); Text("离线成绩记录与分析 · 让每次努力都有迹可循") }
            Section("隐私") { Text("成绩、用户档案、备注与壁纸默认保存在本机。主动使用 iCloud 备份后，完整备份会存入你的 iCloud Drive。应用不接入广告或分析服务。导出文件包含个人信息，完整备份默认未加密，请自行保管。") }
            Section("支持") { Text("如需反馈问题，请附上应用版本和重现步骤，避免公开真实姓名与成绩。"); Link("项目主页",destination: URL(string: "https://github.com/L1angK1NG/StudyTrack")!) }
            Section("开源组件") {
                Text("GRDB.swift · MIT\nZIPFoundation · MIT\nSwift Crypto · Apache 2.0（仅跨平台测试）")
                Text("完整许可随源码的第三方许可目录提供。")
                ForEach(["GRDB","ZIPFoundation"],id: \.self) { name in
                    NavigationLink(name) {
                        ScrollView {
                            Text(license(name)).font(.footnote).textSelection(.enabled).padding()
                        }.navigationTitle(name)
                    }
                }
            }
        }.studyCanvas().navigationTitle("关于与支持").navigationBarTitleDisplayMode(.inline)
    }
    func license(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name,withExtension: "txt",subdirectory: "Licenses") ?? Bundle.main.url(forResource: name,withExtension: "txt"),
              let text = try? String(contentsOf: url,encoding: .utf8) else { return "许可文件未能读取，请查阅项目源码中的 Resources/Licenses。" }
        return text
    }
}

enum AppVersion {
    static var text: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "版本 \(version) (\(build)) · iOS"
    }
}
