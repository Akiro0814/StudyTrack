import SwiftUI
import UniformTypeIdentifiers
import StudyTrackCore

extension UTType {
    static var studytrackBackup: UTType { UTType(exportedAs: "com.repea.studytrack.ios.backup",conformingTo: .zip) }
    static var studytrackXLSX: UTType { UTType(importedAs: "org.openxmlformats.spreadsheetml.sheet",conformingTo: .zip) }
}
private struct ShareFile: Identifiable { let id = UUID(); let url: URL }
struct DataTransferView: View {
    @Environment(AppModel.self) private var model
    @State private var choosing = false
    @State private var restoring = false
    @State private var plan: ImportPlan?
    @State private var backup: VerifiedBackup?
    @State private var restoreRevision = 0
    @State private var report: ImportReport?
    @State private var validOnly = false
    @State private var conversions = false
    @State private var share: ShareFile?
    @State private var confirmRestore = false
    @State private var pendingWorkbook: ParsedWorkbook?
    @State private var pendingDigest = ""
    @State private var termMappings: [String: SchoolTerm] = [:]
    @State private var mapping = false
    var body: some View {
        List {
            Section("Excel 成绩交换") {
                Button("导入 .xlsx",systemImage: "square.and.arrow.down") { restoring = false; choosing = true }
                Button("导出当前学期 .xlsx",systemImage: "square.and.arrow.up") { Task { await exportXLSX() } }
                Text("支持普通未加密 .xlsx；旧 .xls 请先转换。必需列：科目、时间、分数。日期文本使用 YYYY-MM-DD，最多 10000 行。").font(.caption).foregroundStyle(.secondary)
            }
            Section("完整备份") {
                NavigationLink("iCloud 云备份与恢复") { CloudBackupView() }
                Button("导出全部用户与学期",systemImage: "externaldrive.badge.plus") { Task { await exportBackup() } }
                Button("检查并恢复完整备份",systemImage: "arrow.counterclockwise") { restoring = true; choosing = true }
                Button("检查上次替换前的本机快照") {
                    Task { _ = await model.perform {
                        guard let files = model.files, let store = model.store else { return }
                        let data = try await files.latestRecovery()
                        backup = try await Task.detached { try BackupCodec.decode(data) }.value
                        restoreRevision = try await store.revision(); plan = nil
                    } }
                }
                Text("包括空科目、设置和资源。备份未加密；恢复将替换本机全部用户与成绩，建议先导出本机备份。").font(.caption).foregroundStyle(.secondary)
            }
            if let plan {
                Section("导入预览") {
                    Text("目标：\(model.currentUser?.name ?? "") / \(model.currentSemester?.name ?? "")")
                    LabeledContent("可新增",value: "\(plan.rows.count)")
                    LabeledContent("重复 / 内容冲突",value: "\(plan.duplicates) / \(plan.conflicts)")
                    Text("新学期：\(plan.newSemesters.joined(separator: "、"))")
                    Text("新科目：\(plan.newSubjects.joined(separator: "、"))")
                    Toggle("仅导入有效行，跳过错误行",isOn: $validOnly)
                    Toggle("接受已列出的日期与分类转换",isOn: $conversions)
                    ForEach(plan.issues.prefix(100)) { issue in Label("第 \(issue.row) 行：\(issue.reason)",systemImage: issue.warning ? "info.circle" : "exclamationmark.circle").font(.caption) }
                    if plan.issues.count > 100 { Text("其余问题将在完整 JSON 报告中提供。") }
                    Button("确认导入") { Task { await commit(plan) } }.disabled(plan.rows.isEmpty || (!validOnly && plan.issues.contains { !$0.warning }))
                    Button("取消预览",role: .cancel) { self.plan = nil }
                }
            }
            if let backup {
                Section("恢复预览") {
                    Text("来源：\(backup.manifest.sourcePlatform) · \(backup.manifest.exportedAt)")
                    Text("\(backup.snapshot.users.count) 位用户，\(backup.snapshot.semesters.count) 个学期，\(backup.snapshot.subjects.count) 个科目，\(backup.snapshot.exams.count) 条成绩，\(backup.snapshot.assets.count) 个资源。")
                    Text("原有用户、成绩、设置及未保存草稿将被替换。附件会保留在备份中，首版不提供附件编辑。")
                    Button("替换本机全部数据",role: .destructive) { confirmRestore = true }
                    Button("取消恢复",role: .cancel) { self.backup = nil }
                }
            }
            if let report {
                Section("导入报告") {
                    Text("新增 \(report.imported)，重复 \(report.duplicates)，冲突 \(report.conflicts)，错误 \(report.issues.filter { !$0.warning }.count)。")
                    Button("导出完整 JSON 报告") { Task { _ = await model.perform { if let url = try await model.files?.export(JSONEncoder().encode(report),name: "导入报告.json") { share = ShareFile(url: url) } } } }
                }
            }
        }.studyCanvas().navigationTitle("数据与备份").navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $choosing,allowedContentTypes: restoring ? [.studytrackBackup,.zip,.data] : [.studytrackXLSX,.zip,.data,.item],allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls): if let file = urls.first { Task { await inspect(file) } }
                case .failure(let error): if (error as NSError).code != NSUserCancelledError { model.error = "文件未能打开，请等待下载完成后重试。" }
                }
            }
            .sheet(item: $share) { file in ShareSheet(url: file.url) }
            .sheet(isPresented: $mapping) {
                NavigationStack {
                    Form {
                        Text("将表格中的学期对应到标准学期后继续预览。原始文件不变。")
                        ForEach(termMappings.keys.sorted(),id: \.self) { name in
                            Section(name) { SchoolTermPicker(term: Binding(get: { termMappings[name]! },set: { termMappings[name] = $0 })) }
                        }
                    }.navigationTitle("对应历史学期").toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { mapping = false; pendingWorkbook = nil } }
                        ToolbarItem(placement: .confirmationAction) { Button("继续预览") { Task { await applyMappings() } } }
                    }
                }
            }
            .confirmationDialog("确认替换本机全部数据？此操作会清理草稿。",isPresented: $confirmRestore,titleVisibility: .visible) {
                Button("确认替换",role: .destructive) { Task { await restore() } }
            }
    }
    func inspect(_ url: URL) async {
        let isBackup = restoring
        _ = await model.perform {
            guard let files = model.files, let store = model.store, let scope = model.scope else { return }
            let data = try await files.stageExternal(url,limit: (isBackup ? 100 : 20)*1024*1024)
            if isBackup {
                let inspected = try await Task.detached { try BackupCodec.decode(data) }.value
                restoreRevision = try await store.revision(); backup = inspected; plan = nil
            } else {
                guard url.pathExtension.lowercased() == "xlsx" else { throw StudyError.unsupported("请先将文件转换为 .xlsx。") }
                let parsed = try await Task.detached { try XLSXCodec.decode(data) }.value
                let existing = try await store.semesters(userID: scope.userID)
                let unknown = Set(parsed.rows.map(\.semester).filter { name in !name.isEmpty && SchoolTerm.recognize(name) == nil && !existing.contains(where: { term in term.name == name }) })
                pendingDigest = SafeArchive.sha256(data)
                if !unknown.isEmpty {
                    pendingWorkbook = parsed; termMappings = Dictionary(uniqueKeysWithValues: unknown.map { ($0,model.currentSemester?.schoolTerm ?? SchoolTerm(stage: .high,year: 1,half: 1)) }); mapping = true
                } else { plan = try await store.previewImport(parsed,scope: scope,fileDigest: pendingDigest) }
                backup = nil; validOnly = false; conversions = false
            }
        }
    }
    func applyMappings() async {
        guard var parsed = pendingWorkbook,let scope = model.scope else { return }
        for index in parsed.rows.indices { if let term = termMappings[parsed.rows[index].semester] { parsed.rows[index].semester = term.label } }
        if await model.perform({ plan = try await model.store?.previewImport(parsed,scope: scope,fileDigest: pendingDigest) }) { mapping = false; pendingWorkbook = nil }
    }
    func commit(_ plan: ImportPlan) async {
        if await model.perform({ report = try await model.store?.commitImport(plan,validRowsOnly: validOnly,acceptConversions: conversions) }) { self.plan = nil }
    }
    func exportXLSX() async {
        _ = await model.perform {
            guard let scope = model.scope, let rows = try await model.store?.exportRows(scope: scope) else { return }
            let data = try await Task.detached { try XLSXCodec.encode(rows) }.value
            if let url = try await model.files?.export(data,name: "学迹成绩.xlsx") { share = ShareFile(url: url) }
        }
    }
    func exportBackup() async {
        _ = await model.perform {
            guard let snapshot = try await model.store?.snapshot(), let files = model.files else { return }
            let resources = try await files.bytes(for: snapshot.assets)
            let data = try await Task.detached { try BackupCodec.encode(snapshot,resources: resources) }.value
            share = ShareFile(url: try await files.export(data,name: "学迹完整备份.studytrackbackup"))
        }
    }
    func restore() async {
        guard let backup else { return }
        if await model.perform({
            guard let files = model.files, let store = model.store else { return }
            // Retain a recoverable local pre-restore snapshot before replacing anything.
            let old = try await store.snapshot(), resources = try await files.bytes(for: old.assets)
            let rollback = try await Task.detached { try BackupCodec.encode(old,resources: resources) }.value
            try await files.saveRecovery(rollback)
            let snapshot = try await files.install(backup)
            try await store.restore(snapshot,backupID: backup.manifest.backupID,expectedRevision: restoreRevision)
            model.selectionRevision += 1
        }) { self.backup = nil; plan = nil; model.notice = "完整恢复已完成。" }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url],applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
