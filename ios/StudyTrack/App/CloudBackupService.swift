import Foundation
import StudyTrackCore

struct CloudBackupFile: Identifiable, Sendable {
    let url: URL
    let modified: Date
    let uploaded: Bool
    let downloaded: Bool
    let isCloud: Bool
    var errorMessage: String? = nil
    var id: String { url.lastPathComponent }
}

struct CloudBackupDestination: Sendable {
    let url: URL
    let isCloud: Bool
    let userSelected: Bool
}

actor CloudBackupService {
    private let testDirectory: URL?
    private let bookmarkKey: String
    init(testDirectory: URL? = nil,bookmarkKey: String = "studytrack.backup-directory.v1") { self.testDirectory = testDirectory; self.bookmarkKey = bookmarkKey }
    func authorize(_ url: URL) throws {
        try Task.checkCancellation()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw StudyError.invalid("请选择备份文件夹。") }
        let bookmark = try url.bookmarkData(options: .minimalBookmark,includingResourceValuesForKeys: nil,relativeTo: nil)
        UserDefaults.standard.set(bookmark,forKey: bookmarkKey)
    }
    func forgetFolder() { UserDefaults.standard.removeObject(forKey: bookmarkKey) }
    func destination() throws -> CloudBackupDestination? {
        if let testDirectory { return CloudBackupDestination(url: testDirectory,isCloud: false,userSelected: true) }
        if let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            let url: URL
            do { url = try URL(resolvingBookmarkData: bookmark,options: [],relativeTo: nil,bookmarkDataIsStale: &stale) }
            catch { throw StudyError.invalid("备份文件夹的授权已失效，请重新选择文件夹。") }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey,.isUbiquitousItemKey])
                guard values.isDirectory == true else { throw StudyError.invalid("备份文件夹已移动，请重新选择。") }
                if stale { try authorize(url) }
                return CloudBackupDestination(url: url,isCloud: values.isUbiquitousItem == true,userSelected: true)
            } catch { throw StudyError.invalid("无法访问备份文件夹，请重新选择并授权。") }
        }
        // A re-signed installation may have no app-specific iCloud entitlement.
        // User-authorized iCloud Drive folders above do not require that container.
        guard FileManager.default.ubiquityIdentityToken != nil,
              let root = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.repea.studytrack.ios") else { return nil }
        let directory = root.appendingPathComponent("Documents/Backups",isDirectory: true)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        return CloudBackupDestination(url: directory,isCloud: true,userSelected: false)
    }
    private func directory() throws -> CloudBackupDestination {
        guard let location = try destination() else { throw StudyError.invalid("请先选择 iCloud Drive 中的备份文件夹。") }; return location
    }
    func list(discovered: [URL] = []) throws -> [CloudBackupFile] {
        let location = try directory(), directory = location.url
        let access = directory.startAccessingSecurityScopedResource()
        defer { if access { directory.stopAccessingSecurityScopedResource() } }
        try Task.checkCancellation()
        var coordinationError: NSError?, listing: Result<[URL],Error>?
        NSFileCoordinator().coordinate(readingItemAt: directory,options: .withoutChanges,error: &coordinationError) { coordinated in
            listing = Result { try FileManager.default.contentsOfDirectory(at: coordinated,includingPropertiesForKeys: [.contentModificationDateKey],options: []) }
        }
        if let coordinationError { throw coordinationError }
        let local = try listing?.get() ?? []
        let originals = local.map { url in
            let name = url.lastPathComponent
            return name.hasPrefix(".") && name.lowercased().hasSuffix(".studytrackbackup.icloud") ? directory.appendingPathComponent(String(name.dropFirst().dropLast(7))) : url
        }
        let urls = Set(originals + discovered.filter { $0.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL })
        return urls.filter { $0.pathExtension.lowercased() == "studytrackbackup" }.map { url in
            do {
            let placeholder = directory.appendingPathComponent(".\(url.lastPathComponent).icloud")
            let metadataURL = FileManager.default.fileExists(atPath: url.path) || !FileManager.default.fileExists(atPath: placeholder.path) ? url : placeholder
            let values = try metadataURL.resourceValues(forKeys: [.contentModificationDateKey,.isUbiquitousItemKey,.ubiquitousItemIsUploadedKey,.ubiquitousItemDownloadingStatusKey,.ubiquitousItemUploadingErrorKey])
            if let error = values.ubiquitousItemUploadingError { throw error }
            let cloud = location.isCloud || values.isUbiquitousItem == true
            return CloudBackupFile(url: url,modified: values.contentModificationDate ?? .distantPast,uploaded: values.ubiquitousItemIsUploaded ?? false,downloaded: !cloud || values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded,isCloud: cloud)
            } catch {
                // One unavailable/conflicted item must not hide all other backups.
                return CloudBackupFile(url: url,modified: .distantPast,uploaded: false,downloaded: false,isCloud: location.isCloud,errorMessage: error.localizedDescription)
            }
        }.sorted { $0.modified == $1.modified ? $0.id < $1.id : $0.modified > $1.modified }
    }
    func upload(_ data: Data) throws {
        try Task.checkCancellation()
        guard !data.isEmpty,data.count <= 100*1024*1024 else { throw StudyError.invalid("备份为空或超过 100MB。") }
        let directory = try directory().url
        let access = directory.startAccessingSecurityScopedResource()
        defer { if access { directory.stopAccessingSecurityScopedResource() } }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":",with: "-")
        let destination = directory.appendingPathComponent("学迹-\(stamp)-\(UUID().uuidString.prefix(8)).studytrackbackup")
        var coordinationError: NSError?, writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination,options: [],error: &coordinationError) { url in
            do { try Task.checkCancellation(); try data.write(to: url,options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? (writeError as NSError?) { throw error }
    }
    func download(_ file: CloudBackupFile) async throws -> Data {
        try Task.checkCancellation()
        let directory = try directory().url
        let access = directory.startAccessingSecurityScopedResource()
        defer { if access { directory.stopAccessingSecurityScopedResource() } }
        guard file.url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else { throw StudyError.invalid("备份目录已切换，请刷新后重试。") }
        if !file.isCloud { return try coordinatedRead(file.url) }
        // Already-downloaded backups remain restorable without a network.
        let initial = try? file.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey,.ubiquitousItemHasUnresolvedConflictsKey])
        if initial?.ubiquitousItemHasUnresolvedConflicts == true { throw StudyError.invalid("该备份有 iCloud 文件冲突，请在文件 App 中处理后重试。") }
        if initial?.ubiquitousItemDownloadingStatus == .current || initial?.ubiquitousItemDownloadingStatus == .downloaded { return try coordinatedRead(file.url) }
        do { try FileManager.default.startDownloadingUbiquitousItem(at: file.url) }
        catch { if FileManager.default.fileExists(atPath: file.url.path) { return try coordinatedRead(file.url) }; throw error }
        for _ in 0..<120 {
            try Task.checkCancellation()
            // The original path may not exist yet while an iCloud placeholder is
            // being materialized. Keep polling instead of failing on ENOENT.
            guard let values = try? file.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey,.ubiquitousItemDownloadingErrorKey,.ubiquitousItemHasUnresolvedConflictsKey]) else {
                try await Task.sleep(for: .seconds(1)); continue
            }
            if let error = values.ubiquitousItemDownloadingError { throw error }
            if values.ubiquitousItemHasUnresolvedConflicts == true { throw StudyError.invalid("该备份有 iCloud 文件冲突，请在文件 App 中处理后重试。") }
            if values.ubiquitousItemDownloadingStatus == .current || values.ubiquitousItemDownloadingStatus == .downloaded { return try coordinatedRead(file.url) }
            try await Task.sleep(for: .seconds(1))
        }
        throw StudyError.invalid("备份仍在下载，请检查网络后重试。")
    }
    private func coordinatedRead(_ url: URL) throws -> Data {
        try Task.checkCancellation()
        var coordinationError: NSError?, result: Result<Data,Error>?
        NSFileCoordinator().coordinate(readingItemAt: url,options: .withoutChanges,error: &coordinationError) { file in
            result = Result {
                guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 100*1024*1024 else { throw StudyError.invalid("备份超过 100MB。") }
                let data = try Data(contentsOf: file,options: .mappedIfSafe)
                guard data.count <= 100*1024*1024 else { throw StudyError.invalid("备份超过 100MB。") }; try Task.checkCancellation(); return data
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw StudyError.corrupt("云备份读取失败。") }; return try result.get()
    }
}
