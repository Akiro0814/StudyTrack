import SwiftUI
import StudyTrackCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
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
                NavigationLink { SemestersView() } label: { SettingsRow(title: "学期",subtitle: model.currentSemester?.name ?? "管理学习阶段",symbol: "calendar",color: .green) }
            }.buttonStyle(.plain).studySurface()
            VStack(alignment: .leading,spacing: 4) {
                SectionHeading(title: "安心记录").padding(.bottom,10)
                NavigationLink { DataTransferView() } label: { SettingsRow(title: "数据与备份",subtitle: "Excel 交换、完整备份与恢复",symbol: "externaldrive.fill",color: model.accent) }
                Divider().padding(.leading,56)
                NavigationLink { AboutView() } label: { SettingsRow(title: "关于学迹",subtitle: "隐私、支持与开源许可",symbol: "info.circle.fill",color: .secondary) }
            }.buttonStyle(.plain).studySurface()
            VStack(spacing: 8) {
                Label("只属于你的本地学习空间",systemImage: "lock.shield").font(.caption)
                Text(AppVersion.text).font(.caption2)
                Text("作者 L1angK1NG").font(.caption)
                Link("GitHub · L1angK1NG",destination: URL(string: "https://github.com/L1angK1NG")!)
                Link("ljb110814@163.com",destination: URL(string: "mailto:ljb110814@163.com")!)
            }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical,8)
        }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfilesView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var semester = ""
    @State private var adding = false
    @State private var renaming: User?
    @State private var deleting: User?
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
                                guard let snapshot = try await model.store?.snapshot() else { return }
                                deleteDescription = "将删除 \(snapshot.semesters.filter { $0.userID == user.id }.count) 个学期、\(snapshot.subjects.filter { $0.userID == user.id }.count) 个科目和 \(snapshot.exams.filter { $0.userID == user.id }.count) 条成绩。"; deleting = user
                            } catch { model.error = model.friendly(error) }
                        }
                    }
                    Button("重命名") { name = user.name; renaming = user }.tint(.blue)
                }
            }
        }.studyCanvas().navigationTitle("用户管理").navigationBarTitleDisplayMode(.inline)
            .toolbar { if model.preferences.multiUserEnabled { Button("添加用户",systemImage: "plus") { adding = true } } }
            .sheet(isPresented: $adding) { NavigationStack { ProfileSetupForm().toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { adding = false } } } } }
            .alert("重命名用户",isPresented: Binding(get: { renaming != nil },set: { if !$0 { renaming = nil } })) {
                TextField("姓名",text: $name)
                Button("保存") { if let user = renaming { Task { _ = await model.perform { try await model.store?.renameUser(id: user.id,name: name) } } }; renaming = nil }
                Button("取消",role: .cancel) { renaming = nil }
            }
            .confirmationDialog("删除“\(deleting?.name ?? "")”？\n\(deleteDescription)",isPresented: Binding(get: { deleting != nil },set: { if !$0 { deleting = nil } }),titleVisibility: .visible) {
                Button("删除用户及全部数据",role: .destructive) { if let user = deleting { Task { _ = await model.perform { try await model.store?.deleteUser(id: user.id); model.selectionRevision += 1 } } }; deleting = nil }
            }
    }
}

struct SemestersView: View {
    @Environment(AppModel.self) private var model
    @State private var term = SchoolTerm(stage: .high,year: 1,half: 1)
    @State private var editing: Semester?
    @State private var editor = false
    @State private var deleting: Semester?
    @State private var failure: String?
    var body: some View {
        List(model.semesters) { semester in
            Button { Task { await model.switchScope(StudyScope(userID: semester.userID,semesterID: semester.id)) } } label: {
                HStack {
                    VStack(alignment: .leading,spacing: 5) { Text(semester.name); Text(semester.schoolTerm?.stage.label ?? "待归类 · 不计入阶段汇总").font(.caption).foregroundStyle(.secondary) }
                    Spacer(); if semester.id == model.preferences.currentSemesterID { Image(systemName: "checkmark") }
                }
            }.swipeActions {
                Button("删除",role: .destructive) { deleting = semester }
                if semester.schoolTerm == nil { Button("归类") { editing = semester; failure = nil; editor = true }.tint(.blue) }
            }
        }.studyCanvas().navigationTitle("学期管理").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("添加学期",systemImage: "plus") { editing = nil; failure = nil; term = model.currentSemester?.schoolTerm ?? term; editor = true } }
            .sheet(isPresented: $editor) {
                NavigationStack {
                    Form {
                        Section { SchoolTermPicker(term: $term) } footer: { Text(editing == nil ? "自动继承同阶段最近学期的科目与满分，成绩独立保存。" : "保留原学期全部科目和成绩；不会与已有学期合并。") }
                        InlineError(message: failure)
                    }.navigationTitle(editing == nil ? "添加学期" : "归类旧学期")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("取消") { editor = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("保存") {
                                guard let userID = model.preferences.currentUserID else { return }
                                Task { if await model.perform(onError: { failure = $0 }, { _ = try await model.store?.saveSchoolSemester(id: editing?.id,term: term,userID: userID) }) { editor = false } }
                            } }
                        }
                }
            }
            .confirmationDialog("删除学期？仅允许删除非当前且没有科目的学期。",isPresented: Binding(get: { deleting != nil },set: { if !$0 { deleting = nil } }),titleVisibility: .visible) {
                Button("删除学期",role: .destructive) { if let term = deleting { Task { _ = await model.perform { try await model.store?.deleteSemester(id: term.id,userID: term.userID) } } }; deleting = nil }
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
