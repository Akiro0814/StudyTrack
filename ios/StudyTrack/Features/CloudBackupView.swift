import SwiftUI
import StudyTrackCore

struct CloudBackupView: View {
    @Environment(AppModel.self) private var model
    @State private var service = CloudBackupService()
    @State private var files: [CloudBackupFile] = []
    @State private var status = ""
    @State private var working = false
    @State private var backup: VerifiedBackup?
    @State private var revision = 0
    @State private var confirming = false
    @State private var downloadTask: Task<Void,Never>?
    @State private var query = NSMetadataQuery()
    @State private var location: CloudBackupDestination?
    @State private var choosingFolder = false
    @State private var choosingBackup = false
    @State private var backupAfterSelection = false
    var body: some View {
        List {
            Section {
                Button(location?.isCloud == false ? "立即保存完整备份" : "立即备份到 iCloud",systemImage: "icloud.and.arrow.up") {
                    if location == nil { backupAfterSelection = true; choosingFolder = true }
                    else { Task { await upload() } }
                }.disabled(working)
                Button(location == nil ? "选择 iCloud Drive 备份文件夹" : "更换备份文件夹",systemImage: "folder.badge.gearshape") {
                    backupAfterSelection = false; choosingFolder = true
                }.disabled(working)
                if let location {
                    Text("备份位置：\(location.userSelected ? location.url.lastPathComponent : "学迹专属 iCloud 文件夹")").font(.caption)
                    if location.userSelected { Text("请在“文件”中确认此文件夹位于 iCloud Drive；选择本机文件夹仅会保存在本机。").font(.caption).foregroundStyle(.secondary) }
                }
                if location?.userSelected == true { Button("解除此文件夹授权") { Task { await service.forgetFolder(); backup = nil; await refresh() } }.disabled(working) }
                Button("刷新云端备份",systemImage: "arrow.clockwise") { Task { await refresh() } }.disabled(working)
                Button("从文件选择并恢复备份",systemImage: "doc.badge.arrow.up") { choosingBackup = true }.disabled(working)
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
                if working { ProgressView(); Button("取消下载") { downloadTask?.cancel() }.disabled(downloadTask == nil) }
            } footer: { Text("完整保存所有用户、学期、成绩、头像、壁纸与设置。备份由 iCloud Drive 传输；恢复会替换本机数据。") }
            Section("云端备份") {
                if files.isEmpty { Text("暂未发现备份").foregroundStyle(.secondary) }
                ForEach(files) { file in
                    Button {
                        downloadTask = Task { await inspect(file) }
                    } label: {
                        VStack(alignment: .leading,spacing: 6) {
                            Text(file.url.lastPathComponent).font(.subheadline).lineLimit(2)
                            if file.modified != .distantPast { Text(file.modified,format: .dateTime.year().month().day().hour().minute()).font(.caption) }
                            Text(file.errorMessage.map { "此备份暂不可用：" + $0 } ?? (file.isCloud ? (file.uploaded ? "已上传 · 点击检查并恢复" : "已保存 · 等待 iCloud 完成传输") : "已保存到所选文件夹")).font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(working)
                }
            }
            if let backup {
                Section("恢复预览") {
                    Text("\(backup.snapshot.users.count) 位用户 · \(backup.snapshot.semesters.count) 个学期 · \(backup.snapshot.exams.count) 条成绩")
                    Text("来源：\(backup.manifest.exportedAt)").font(.caption)
                    Button("替换本机数据",role: .destructive) { confirming = true }.disabled(working)
                    Button("取消预览") { self.backup = nil }
                }
            }
        }.studyCanvas().navigationTitle("iCloud 云备份")
            .refreshable { if !working { await refresh() } }
            .task {
                query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope,NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope]
                query.predicate = NSPredicate(format: "%K ENDSWITH %@",NSMetadataItemFSNameKey,".studytrackbackup")
                query.start(); await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering,object: query)) { _ in if !working { Task { await refresh() } } }
            .onReceive(NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate,object: query)) { _ in if !working { Task { await refresh() } } }
            .onDisappear { downloadTask?.cancel(); query.stop() }
            .sheet(isPresented: $choosingFolder) {
                StudyDocumentPicker(mode: .folder,onSelection: { url in
                    choosingFolder = false
                    Task {
                        do {
                            try await service.authorize(url); backup = nil; await refresh()
                            if backupAfterSelection { await upload() }
                        } catch { status = "无法授权备份文件夹，请重新选择。\n" + error.localizedDescription }
                        backupAfterSelection = false
                    }
                },onCancel: { choosingFolder = false; backupAfterSelection = false })
            }
            .sheet(isPresented: $choosingBackup) {
                StudyDocumentPicker(onSelection: { url in choosingBackup = false; downloadTask = Task { await inspectExternal(url) } },onCancel: { choosingBackup = false })
            }
            .confirmationDialog("确认恢复？将先保存本机恢复快照，再替换全部数据。",isPresented: $confirming,titleVisibility: .visible) { Button("确认替换",role: .destructive) { Task { await restore() } } }
    }
    func refresh() async {
        query.disableUpdates()
        let urls = query.results.compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemURLKey) as? URL }
        query.enableUpdates()
        do { location = try await service.destination() }
        catch { location = nil; files = []; status = error.localizedDescription; return }
        guard location != nil else { files = []; status = "请选择 iCloud Drive 中的文件夹，即可备份与恢复。"; return }
        do {
            files = try await service.list(discovered: urls); status = files.isEmpty ? "备份文件夹可用，还没有备份。" : "已读取备份列表。"
        } catch { files = []; status = "暂时无法读取备份列表，请检查文件 App 的同步状态后刷新。\n" + error.localizedDescription }
    }
    func upload() async {
        guard !working else { return }
        working = true; defer { working = false }
        do {
            guard let store = model.store,let fileService = model.files else { return }
            let snapshot = try await store.snapshot(), resources = try await fileService.bytes(for: snapshot.assets)
            let bytes = try await Task.detached { try BackupCodec.encode(snapshot,resources: resources) }.value
            try await service.upload(bytes); await refresh(); status = "完整备份已保存到所选位置。iCloud Drive 的上传由系统完成，可在文件 App 查看同步状态。"
        } catch { status = model.friendly(error) }
    }
    func inspectExternal(_ url: URL) async {
        guard !working else { return }
        working = true; backup = nil; status = "正在读取并校验备份…"; defer { working = false; downloadTask = nil }
        do {
            guard let files = model.files else { return }
            let bytes = try await files.stageExternal(url,limit: 100*1024*1024)
            let verified = try await Task.detached { try BackupCodec.decode(bytes) }.value
            try Task.checkCancellation(); revision = try await model.store?.revision() ?? 0; backup = verified; status = "校验通过，请查看恢复预览。"
        } catch { status = model.friendly(error) }
    }
    func inspect(_ file: CloudBackupFile) async {
        guard !working else { return }
        working = true; backup = nil; status = "正在下载并校验备份…"; defer { working = false; downloadTask = nil }
        do {
            let bytes = try await service.download(file)
            let verified = try await Task.detached { try BackupCodec.decode(bytes) }.value
            try Task.checkCancellation(); revision = try await model.store?.revision() ?? 0; backup = verified; status = "校验通过，请查看恢复预览。"
        } catch { status = model.friendly(error) }
    }
    func restore() async {
        guard let backup else { return }; working = true; defer { working = false }
        if await model.perform({
            guard let store = model.store,let files = model.files else { return }
            let old = try await store.snapshot(), resources = try await files.bytes(for: old.assets)
            let rollback = try await Task.detached { try BackupCodec.encode(old,resources: resources) }.value
            try await files.saveRecovery(rollback)
            let snapshot = try await files.install(backup)
            try await store.restore(snapshot,backupID: backup.manifest.backupID,expectedRevision: revision)
            model.recentlyDeleted = nil; model.selectionRevision += 1
        }) { self.backup = nil; status = "iCloud 备份恢复完成。" }
    }
}
