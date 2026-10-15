import Foundation
import StudyTrackCore

struct CloudBackupFile: Identifiable, Sendable {
    let url: URL
    let modified: Date
    let uploaded: Bool
    let downloaded: Bool
    var id: String { url.lastPathComponent }
}

actor CloudBackupService {
    private func directory() throws -> URL {
        guard FileManager.default.ubiquityIdentityToken != nil else { throw StudyError.invalid("请先在系统设置登录 iCloud 并开启 iCloud Drive。") }
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.repea.studytrack.ios") else { throw StudyError.unsupported("iCloud 容器不可用，请检查网络及安装签名是否包含 iCloud 能力。") }
        let directory = root.appendingPathComponent("Documents/Backups",isDirectory: true)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        return directory
    }
    func list(discovered: [URL] = []) throws -> [CloudBackupFile] {
        let directory = try directory()
        let local = try FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: [.contentModificationDateKey,.ubiquitousItemIsUploadedKey,.ubiquitousItemDownloadingStatusKey],options: [])
        let urls = Set(local + discovered.filter { $0.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL })
        return try urls.filter { $0.pathExtension == "studytrackbackup" }.map { url in
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey,.ubiquitousItemIsUploadedKey,.ubiquitousItemDownloadingStatusKey,.ubiquitousItemUploadingErrorKey])
            if let error = values.ubiquitousItemUploadingError { throw error }
            return CloudBackupFile(url: url,modified: values.contentModificationDate ?? .distantPast,uploaded: values.ubiquitousItemIsUploaded ?? false,downloaded: values.ubiquitousItemDownloadingStatus == .current)
        }.sorted { $0.modified > $1.modified }
    }
    func upload(_ data: Data) throws {
        let directory = try directory()
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":",with: "-")
        let destination = directory.appendingPathComponent("学迹-\(stamp)-\(UUID().uuidString.prefix(8)).studytrackbackup")
        var coordinationError: NSError?, writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination,options: [],error: &coordinationError) { url in
            do { try data.write(to: url,options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? (writeError as NSError?) { throw error }
    }
    func download(_ file: CloudBackupFile) async throws -> Data {
        _ = try directory()
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
