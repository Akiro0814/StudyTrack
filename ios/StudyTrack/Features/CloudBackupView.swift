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
    var body: some View {
        List {
            Section {
                Button("立即备份到 iCloud",systemImage: "icloud.and.arrow.up") { Task { await upload() } }.disabled(working)
                Button("刷新云端备份",systemImage: "arrow.clockwise") { Task { await refresh() } }.disabled(working)
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
                            Text(file.modified,format: .dateTime.year().month().day().hour().minute())
                            Text(file.uploaded ? "已上传 · 点击检查并恢复" : "等待 iCloud 完成传输").font(.caption).foregroundStyle(.secondary)
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
            .task {
                query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
                query.predicate = NSPredicate(format: "%K ENDSWITH %@",NSMetadataItemFSNameKey,".studytrackbackup")
                query.start(); await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSMetadataQueryDidFinishGathering,object: query)) { _ in Task { await refresh() } }
            .onReceive(NotificationCenter.default.publisher(for: .NSMetadataQueryDidUpdate,object: query)) { _ in Task { await refresh() } }
            .onDisappear { downloadTask?.cancel(); query.stop() }
            .confirmationDialog("确认恢复？将先保存本机恢复快照，再替换全部数据。",isPresented: $confirming,titleVisibility: .visible) { Button("确认替换",role: .destructive) { Task { await restore() } } }
    }
    func refresh() async {
        query.disableUpdates()
        let urls = query.results.compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemURLKey) as? URL }
        query.enableUpdates()
        do { files = try await service.list(discovered: urls); status = files.isEmpty ? "iCloud 可用，还没有备份。" : "已读取备份列表。" } catch { status = error.localizedDescription }
    }
    func upload() async {
        working = true; defer { working = false }
        do {
            guard let store = model.store,let fileService = model.files else { return }
            let snapshot = try await store.snapshot(), resources = try await fileService.bytes(for: snapshot.assets)
            let bytes = try await Task.detached { try BackupCodec.encode(snapshot,resources: resources) }.value
            try await service.upload(bytes); await refresh(); status = "备份已写入 iCloud 容器，上传由系统完成。刷新列表查看传输状态。"
        } catch { status = model.friendly(error) }
    }
    func inspect(_ file: CloudBackupFile) async {
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
