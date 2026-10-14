import Foundation
import ZIPFoundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public enum SafeArchive {
    public static func validatePath(_ path: String) throws {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains(":"), !path.contains("\0"),
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { throw StudyError.corrupt("压缩包包含不安全路径。") }
    }
    public static func read(_ data: Data, compressedLimit: Int, expandedLimit: Int, fileLimit: Int = 10000) throws -> [String: Data] {
        guard data.count <= compressedLimit else { throw StudyError.invalid("压缩文件超过大小限制。") }
        let archive = try Archive(data: data,accessMode: .read)
        var seen = Set<String>(), total: UInt64 = 0, files: [String: Data] = [:]
        // Preflight every entry before decompressing any payload.
        for entry in archive {
            let path = entry.type == .directory && entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
            try validatePath(path)
            guard seen.insert(path).inserted, seen.count <= fileLimit, entry.type != .symlink else { throw StudyError.corrupt("压缩包有重名、链接或过多文件。") }
            guard entry.uncompressedSize <= UInt64(expandedLimit)-total else { throw StudyError.invalid("解压内容超过大小限制。") }
            total += entry.uncompressedSize
        }
        for entry in archive where entry.type == .file {
            var payload = Data()
            let crc = try archive.extract(entry) { chunk in
                guard payload.count + chunk.count <= expandedLimit else { throw StudyError.invalid("解压超限。") }; payload.append(chunk)
            }
            guard UInt64(payload.count) == entry.uncompressedSize, crc == entry.checksum else { throw StudyError.corrupt("压缩内容校验失败。") }
            files[entry.path] = payload
        }
        return files
    }
    public static func write(_ files: [String: Data]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        for path in files.keys.sorted() {
            try validatePath(path); let payload = files[path]!
            try archive.addEntry(with: path,type: .file,uncompressedSize: Int64(payload.count),compressionMethod: .deflate) { position, size in
                payload.subdata(in: Int(position)..<min(Int(position)+size,payload.count))
            }
        }
        guard let data = archive.data else { throw StudyError.corrupt("压缩失败。") }; return data
    }
    public static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x",$0) }.joined() }
}
