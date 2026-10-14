import Foundation

public struct BackupManifest: Codable, Sendable {
    public struct File: Codable, Sendable { public var path: String; public var byteCount: Int; public var sha256: String }
    public var format: String; public var formatVersion: Int; public var backupID: String; public var sourceDatasetID: String
    public var sourcePlatform: String; public var sourceAppVersion: String; public var exportedAt: String
    public var recordCounts: [String: Int]; public var files: [File]
}
public struct VerifiedBackup: Sendable {
    public let manifest: BackupManifest; public let snapshot: Snapshot; public let resources: [String: Data]
}
public enum BackupCodec {
    static func wireData(_ snapshot: Snapshot) throws -> Data {
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        obj.removeValue(forKey: "datasetID"); obj.removeValue(forKey: "preferences")
        obj["subjects"] = try snapshot.subjects.map { subject -> [String: Any] in
            var v = try JSONSerialization.jsonObject(with: JSONEncoder().encode(subject)) as! [String: Any]
            v["fullScore"] = Score.fixed(subject.fullScore); return v
        }
        obj.removeValue(forKey: "exams")
        obj["examRecords"] = try snapshot.exams.map { exam -> [String: Any] in
            var v = try JSONSerialization.jsonObject(with: JSONEncoder().encode(exam)) as! [String: Any]
            v["score"] = Score.fixed(exam.score); return v
        }
        return try JSONSerialization.data(withJSONObject: obj,options: [.sortedKeys])
    }
    public static func encode(_ snapshot: Snapshot, resources: [String: Data]) throws -> Data {
        try StudyStore.validateSnapshot(snapshot)
        var files = ["data.json": try wireData(snapshot), "preferences.json": try JSONEncoder().encode(snapshot.preferences)]
        for asset in snapshot.assets {
            guard let bytes = resources[asset.relativePath], bytes.count == asset.byteCount, SafeArchive.sha256(bytes) == asset.sha256 else { throw StudyError.corrupt("资源缺失或损坏，备份未完成。") }
            files[asset.relativePath] = bytes
        }
        let manifest = BackupManifest(format: "studytrack-backup",formatVersion: 1,backupID: UUID().uuidString.lowercased(),sourceDatasetID: snapshot.datasetID,sourcePlatform: "ios",sourceAppVersion: "1.0",exportedAt: ISO8601DateFormatter().string(from: Date()),recordCounts: counts(snapshot),files: files.keys.sorted().map { .init(path: $0,byteCount: files[$0]!.count,sha256: SafeArchive.sha256(files[$0]!)) })
        files["manifest.json"] = try JSONEncoder().encode(manifest)
        guard files.values.reduce(0, { $0+$1.count }) <= 500*1024*1024 else { throw StudyError.invalid("备份内容超过 500MB。") }
        let result = try SafeArchive.write(files)
        guard result.count <= 100*1024*1024 else { throw StudyError.invalid("备份超过 100MB。") }; return result
    }
    public static func decode(_ data: Data) throws -> VerifiedBackup {
        let files = try SafeArchive.read(data,compressedLimit: 100*1024*1024,expandedLimit: 500*1024*1024)
        guard let raw = files["manifest.json"], raw.count <= 4*1024*1024 else { throw StudyError.corrupt("缺少有效备份清单。") }
        let manifest = try JSONDecoder().decode(BackupManifest.self,from: raw)
        guard manifest.format == "studytrack-backup", manifest.formatVersion == 1,
              UUID(uuidString: manifest.backupID) != nil, StudyStore.validTimestamp(manifest.exportedAt),
              Set(manifest.files.map(\.path)).count == manifest.files.count,
              Set(manifest.files.map(\.path)) == Set(files.keys).subtracting(["manifest.json"]) else { throw StudyError.corrupt("不支持的备份版本或清单不完整。") }
        for item in manifest.files {
            guard let bytes = files[item.path], bytes.count == item.byteCount, SafeArchive.sha256(bytes) == item.sha256 else { throw StudyError.corrupt("备份文件散列校验失败。") }
        }
        guard let dataJSON = files["data.json"], let preferencesJSON = files["preferences.json"], preferencesJSON.count <= 1024*1024,
              var object = try JSONSerialization.jsonObject(with: dataJSON) as? [String: Any],
              let subjects = object["subjects"] as? [[String: Any]], let exams = object["examRecords"] as? [[String: Any]] else { throw StudyError.corrupt("备份数据不完整。") }
        object["subjects"] = try subjects.map { original in
            var x = original; guard let score = x["fullScore"] as? String else { throw StudyError.corrupt("满分格式错误。") }
            x["fullScore"] = try Score.parse(score); return x
        }
        object["exams"] = try exams.map { original in
            var x = original; guard let score = x["score"] as? String else { throw StudyError.corrupt("成绩格式错误。") }
            x["score"] = try Score.parse(score); return x
        }
        object.removeValue(forKey: "examRecords"); object["datasetID"] = manifest.sourceDatasetID
        object["preferences"] = try JSONSerialization.jsonObject(with: preferencesJSON)
        let snapshot = try JSONDecoder().decode(Snapshot.self,from: JSONSerialization.data(withJSONObject: object))
        guard manifest.recordCounts == counts(snapshot) else { throw StudyError.corrupt("备份记录数量不符。") }
        try StudyStore.validateSnapshot(snapshot)
        var resources: [String: Data] = [:]
        for asset in snapshot.assets {
            try SafeArchive.validatePath(asset.relativePath)
            guard asset.relativePath.hasPrefix("assets/"), let bytes = files[asset.relativePath], bytes.count == asset.byteCount,
                  SafeArchive.sha256(bytes) == asset.sha256 else { throw StudyError.corrupt("备份资源引用或散列无效。") }
            resources[asset.relativePath] = bytes
        }
        guard Set(files.keys) == Set(["manifest.json","data.json","preferences.json"] + snapshot.assets.map(\.relativePath)) else { throw StudyError.corrupt("备份包含未声明资源。") }
        return VerifiedBackup(manifest: manifest,snapshot: snapshot,resources: resources)
    }
    static func counts(_ s: Snapshot) -> [String: Int] {
        ["users": s.users.count,"semesters": s.semesters.count,"subjects": s.subjects.count,"examRecords": s.exams.count,"assets": s.assets.count,"legacyIDMap": s.legacyIDMap.count]
    }
}
