import SwiftUI
import StudyTrackCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        List {
            Section("学习档案") {
                NavigationLink { ProfilesView() } label: { Label("用户管理",systemImage: "person.crop.circle") }
                NavigationLink { SemestersView() } label: { Label("学期管理",systemImage: "calendar") }
                LabeledContent("当前用户",value: model.currentUser?.name ?? "—")
                LabeledContent("当前学期",value: model.currentSemester?.name ?? "—")
            }
            Section("数据") { NavigationLink { DataTransferView() } label: { Label("导入、导出与完整备份",systemImage: "externaldrive") } }
            Section("外观") { NavigationLink { PersonalizationView() } label: { Label("个性化",systemImage: "paintpalette") } }
            Section { NavigationLink("关于与支持") { AboutView() } }
        }.navigationTitle("设置")
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
                    guard model.preferences.multiUserEnabled || user.id == model.preferences.currentUserID else { return }
                    Task {
                        do { if let term = try await model.store?.semesters(userID: user.id).first { await model.switchScope(StudyScope(userID: user.id,semesterID: term.id)) } }
                        catch { model.error = model.friendly(error) }
                    }
                } label: {
                    HStack { VStack(alignment: .leading) { Text(user.name); Text(String(user.id.prefix(8))).font(.caption).foregroundStyle(.secondary) }; Spacer(); if user.id == model.preferences.currentUserID { Image(systemName: "checkmark") } }
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
        }.navigationTitle("用户管理")
            .toolbar { Button("添加用户",systemImage: "plus") { name = ""; semester = ""; adding = true } }
            .alert("添加用户",isPresented: $adding) {
                TextField("姓名",text: $name); TextField("初始学期",text: $semester)
                Button("添加") { Task { _ = await model.perform { _ = try await model.store?.createUser(name: name,semester: semester); model.selectionRevision += 1 } } }
                Button("取消",role: .cancel) {}
            }
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
    @State private var name = ""
    @State private var editing: Semester?
    @State private var editor = false
    @State private var deleting: Semester?
    var body: some View {
        List(model.semesters) { term in
            Button { Task { await model.switchScope(StudyScope(userID: term.userID,semesterID: term.id)) } } label: {
                HStack { Text(term.name); Spacer(); if term.id == model.preferences.currentSemesterID { Image(systemName: "checkmark") } }
            }.swipeActions {
                Button("删除",role: .destructive) { deleting = term }
                Button("重命名") { editing = term; name = term.name; editor = true }.tint(.blue)
            }
        }.navigationTitle("学期管理")
            .toolbar { Button("添加学期",systemImage: "plus") { editing = nil; name = ""; editor = true } }
            .alert(editing == nil ? "添加学期" : "重命名学期",isPresented: $editor) {
                TextField("学期名称",text: $name)
                Button("保存") {
                    guard let userID = model.preferences.currentUserID else { return }
                    let id = editing?.id
                    Task { _ = await model.perform { _ = try await model.store?.saveSemester(id: id,name: name,userID: userID) } }
                }
                Button("取消",role: .cancel) {}
            }
            .confirmationDialog("删除学期？仅允许删除非当前且没有科目的学期。",isPresented: Binding(get: { deleting != nil },set: { if !$0 { deleting = nil } }),titleVisibility: .visible) {
                Button("删除学期",role: .destructive) { if let term = deleting { Task { _ = await model.perform { try await model.store?.deleteSemester(id: term.id,userID: term.userID) } } }; deleting = nil }
            }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section { Label("学迹 StudyTrack",systemImage: "chart.xyaxis.line").font(.title2.bold()); Text("iOS 1.0 · 离线成绩记录与分析") }
            Section("隐私") { Text("成绩、用户档案、备注与壁纸保存在本机。应用不接入广告、网络账号或分析服务。导出文件包含个人信息，完整备份默认未加密，请自行保管。") }
            Section("支持") { Text("如需反馈问题，请附上应用版本和重现步骤，避免公开真实姓名与成绩。"); Link("项目主页",destination: URL(string: "https://github.com/wznb666-0814/StudyTrack")!) }
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
        }.navigationTitle("关于与支持")
    }
    func license(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name,withExtension: "txt",subdirectory: "Licenses") ?? Bundle.main.url(forResource: name,withExtension: "txt"),
              let text = try? String(contentsOf: url,encoding: .utf8) else { return "许可文件未能读取，请查阅项目源码中的 Resources/Licenses。" }
        return text
    }
}
