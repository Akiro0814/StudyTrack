import Foundation
import StudyTrackCore

struct CloudBackupFile: Identifiable, Sendable {
    let url: URL
    let modified: Date
    let uploaded: Bool
    let downloaded: Bool
    let isCloud: Bool
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
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw StudyError.invalid("请选择备份文件夹。") }
        let bookmark = try url.bookmarkData(options: .minimalBookmark,includingResourceValuesForKeys: nil,relativeTo: nil)
        UserDefaults.standard.set(bookmark,forKey: bookmarkKey)
    }
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
        let local = try FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: [.contentModificationDateKey],options: [])
        let originals = local.map { url in
            let name = url.lastPathComponent
            return name.hasPrefix(".") && name.hasSuffix(".studytrackbackup.icloud") ? directory.appendingPathComponent(String(name.dropFirst().dropLast(7))) : url
        }
        let urls = Set(originals + discovered.filter { $0.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL })
        return try urls.filter { $0.pathExtension.lowercased() == "studytrackbackup" }.map { url in
            let placeholder = directory.appendingPathComponent(".\(url.lastPathComponent).icloud")
            let metadataURL = FileManager.default.fileExists(atPath: url.path) || !FileManager.default.fileExists(atPath: placeholder.path) ? url : placeholder
            let values = try metadataURL.resourceValues(forKeys: [.contentModificationDateKey,.isUbiquitousItemKey,.ubiquitousItemIsUploadedKey,.ubiquitousItemDownloadingStatusKey,.ubiquitousItemUploadingErrorKey])
            if let error = values.ubiquitousItemUploadingError { throw error }
            let cloud = location.isCloud || values.isUbiquitousItem == true
            return CloudBackupFile(url: url,modified: values.contentModificationDate ?? .distantPast,uploaded: values.ubiquitousItemIsUploaded ?? false,downloaded: !cloud || values.ubiquitousItemDownloadingStatus == .current,isCloud: cloud)
        }.sorted { $0.modified > $1.modified }
    }
    func upload(_ data: Data) throws {
        let directory = try directory().url
        let access = directory.startAccessingSecurityScopedResource()
        defer { if access { directory.stopAccessingSecurityScopedResource() } }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":",with: "-")
        let destination = directory.appendingPathComponent("学迹-\(stamp)-\(UUID().uuidString.prefix(8)).studytrackbackup")
        var coordinationError: NSError?, writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination,options: [],error: &coordinationError) { url in
            do { try data.write(to: url,options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? (writeError as NSError?) { throw error }
    }
    func download(_ file: CloudBackupFile) async throws -> Data {
        let directory = try directory().url
        let access = directory.startAccessingSecurityScopedResource()
        defer { if access { directory.stopAccessingSecurityScopedResource() } }
        guard file.url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else { throw StudyError.invalid("备份目录已切换，请刷新后重试。") }
        if !file.isCloud { return try coordinatedRead(file.url) }
        try FileManager.default.startDownloadingUbiquitousItem(at: file.url)
        for _ in 0..<120 {
            try Task.checkCancellation()
            let values = try file.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey,.ubiquitousItemDownloadingErrorKey,.ubiquitousItemHasUnresolvedConflictsKey])
            if let error = values.ubiquitousItemDownloadingError { throw error }
            if values.ubiquitousItemHasUnresolvedConflicts == true { throw StudyError.invalid("该备份有 iCloud 文件冲突，请在文件 App 中处理后重试。") }
            if values.ubiquitousItemDownloadingStatus == .current { return try coordinatedRead(file.url) }
            try await Task.sleep(for: .seconds(1))
        }
        throw StudyError.invalid("备份仍在下载，请检查网络后重试。")
    }
    private func coordinatedRead(_ url: URL) throws -> Data {
        var coordinationError: NSError?, result: Result<Data,Error>?
        NSFileCoordinator().coordinate(readingItemAt: url,options: .withoutChanges,error: &coordinationError) { file in
            result = Result {
                guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 100*1024*1024 else { throw StudyError.invalid("备份超过 100MB。") }
                let data = try Data(contentsOf: file,options: .mappedIfSafe)
                guard data.count <= 100*1024*1024 else { throw StudyError.invalid("备份超过 100MB。") }; return data
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw StudyError.corrupt("云备份读取失败。") }; return try result.get()
    }
}
