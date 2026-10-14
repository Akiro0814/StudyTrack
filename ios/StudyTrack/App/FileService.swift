import Foundation
import StudyTrackCore
import ImageIO
import UniformTypeIdentifiers

actor FileService {
    let root: URL
    init(root: URL) { self.root = root }
    func stageExternal(_ url: URL, limit: Int) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?, result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url,options: .withoutChanges,error: &coordinationError) { coordinated in
            result = Result {
                let size = try coordinated.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= limit else { throw StudyError.invalid("所选文件超过大小限制。") }
                let data = try Data(contentsOf: coordinated,options: .mappedIfSafe)
                guard data.count <= limit else { throw StudyError.invalid("所选文件超过大小限制。") }; return data
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw StudyError.corrupt("无法读取所选文件，请等待 iCloud 下载后重试。") }; return try result.get()
    }
    func export(_ data: Data, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name); try data.write(to: file,options: .atomic); return file
    }
    func bytes(for assets: [Asset]) throws -> [String: Data] {
        var resources: [String: Data] = [:]
        for asset in assets {
            try SafeArchive.validatePath(asset.relativePath)
            let data = try Data(contentsOf: root.appendingPathComponent(asset.relativePath),options: .mappedIfSafe)
            guard SafeArchive.sha256(data) == asset.sha256, data.count == asset.byteCount else { throw StudyError.corrupt("本机资源损坏，无法生成完整备份。") }
            resources[asset.relativePath] = data
        }; return resources
    }
    func install(_ backup: VerifiedBackup) throws -> Snapshot {
        var snapshot = backup.snapshot
        for i in snapshot.assets.indices {
            let asset = snapshot.assets[i]
            guard let data = backup.resources[asset.relativePath] else { throw StudyError.corrupt("恢复资源缺失。") }
            let ext = URL(fileURLWithPath: asset.relativePath).pathExtension
            let path = "assets/\(asset.sha256)\(ext.isEmpty ? "" : "."+ext)"
            try writeImmutable(data,path: path); snapshot.assets[i].relativePath = path
        }; return snapshot
    }
    func writeImmutable(_ data: Data, path: String) throws {
        try SafeArchive.validatePath(path)
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: file.path) {
            guard SafeArchive.sha256(try Data(contentsOf: file)) == SafeArchive.sha256(data) else { throw StudyError.corrupt("资源路径内容冲突。") }
        } else { try data.write(to: file,options: .atomic) }
    }
    func saveWallpaper(_ data: Data) throws -> Asset {
        guard data.count <= 50*1024*1024, let source = CGImageSourceCreateWithData(data as CFData,nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways: true,kCGImageSourceCreateThumbnailWithTransform: true,kCGImageSourceThumbnailMaxPixelSize: 2560] as CFDictionary) else { throw StudyError.invalid("照片无法读取或超过 50MB。") }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output,UTType.jpeg.identifier as CFString,1,nil) else { throw StudyError.corrupt("无法保存壁纸。") }
        CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw StudyError.corrupt("壁纸编码失败。") }
        let bytes = output as Data, hash = SafeArchive.sha256(bytes), path = "assets/\(hash).jpg"
        try writeImmutable(bytes,path: path)
        return Asset(id: UUID().uuidString.lowercased(),relativePath: path,mimeType: "image/jpeg",sha256: hash,byteCount: bytes.count)
    }
    func wallpaper(_ asset: Asset) throws -> Data { try Data(contentsOf: root.appendingPathComponent(asset.relativePath)) }
    func saveRecovery(_ data: Data) throws {
        let path = "recovery/\(UUID().uuidString.lowercased()).studytrackbackup"
        try writeImmutable(data,path: path)
        try JSONEncoder().encode(path).write(to: root.appendingPathComponent("recovery/index.json"),options: .atomic)
    }
    func latestRecovery() throws -> Data {
        let index = root.appendingPathComponent("recovery/index.json")
        guard FileManager.default.fileExists(atPath: index.path) else { throw StudyError.invalid("还没有替换恢复前的本机快照。") }
        let path = try JSONDecoder().decode(String.self,from: Data(contentsOf: index)); try SafeArchive.validatePath(path)
        guard path.hasPrefix("recovery/") else { throw StudyError.corrupt("恢复快照索引无效。") }
        return try Data(contentsOf: root.appendingPathComponent(path),options: .mappedIfSafe)
    }
}
