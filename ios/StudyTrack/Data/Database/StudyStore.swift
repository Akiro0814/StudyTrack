import Foundation
import GRDB

public actor StudyStore: ExamRepository {
    let queue: DatabaseQueue
    public init(path: String) throws {
        var config = Configuration(); config.foreignKeysEnabled = true
        queue = try DatabaseQueue(path: path, configuration: config)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            guard let url = Bundle.module.url(forResource: "schema", withExtension: "sql") else { throw StudyError.corrupt("数据库结构资源缺失。") }
            try db.execute(sql: String(contentsOf: url, encoding: .utf8))
            try db.execute(sql: "INSERT INTO preferences_state VALUES(1,0,?)", arguments: [try Self.json(Preferences())])
            try db.execute(sql: "INSERT INTO app_metadata VALUES('dataset_id',?)", arguments: [Self.id()])
            try db.execute(sql: "INSERT INTO app_metadata VALUES('revision','0')")
        }
        try migrator.migrate(queue)
        try queue.write { db in
            var preferences = try Self.preferences(db)
            try Self.repairSelection(db, preferences: &preferences)
            try Self.writePreferences(db, preferences)
            try db.execute(sql: "UPDATE restore_operations SET phase='completed' WHERE phase='dbCommitted'")
        }
    }
    static func id() -> String { UUID().uuidString.lowercased() }
    static func now() -> String { ISO8601DateFormatter().string(from: Date()) }
    static func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try JSONEncoder().encode(value), as: UTF8.self) }
    static func decode<T: Decodable>(_ type: T.Type, _ text: String) throws -> T { try JSONDecoder().decode(type, from: Data(text.utf8)) }
    static func name(_ text: String) throws -> String {
        let value = normalize(text)
        guard !value.isEmpty, value.count <= 100 else { throw StudyError.invalid("名称须为 1–100 个字符。") }; return value
    }
    static func bump(_ db: Database) throws { try db.execute(sql: "UPDATE app_metadata SET value=CAST(value AS INTEGER)+1 WHERE key='revision'") }
    static func preferences(_ db: Database) throws -> Preferences {
        try decode(Preferences.self, String.fetchOne(db, sql: "SELECT payload_json FROM preferences_state WHERE singleton_id=1")!)
    }
    static func writePreferences(_ db: Database, _ preferences: Preferences) throws {
        try db.execute(sql: "UPDATE preferences_state SET revision=revision+1,payload_json=? WHERE singleton_id=1", arguments: [try json(preferences)])
    }
    static func repairSelection(_ db: Database, preferences p: inout Preferences) throws {
        if try Int.fetchOne(db, sql: "SELECT count(*) FROM users WHERE id=?", arguments: [p.currentUserID]) == 0 {
            p.currentUserID = try String.fetchOne(db, sql: "SELECT id FROM users ORDER BY created_at,id LIMIT 1")
        }
        if try Int.fetchOne(db, sql: "SELECT count(*) FROM semesters WHERE id=? AND user_id=?", arguments: [p.currentSemesterID,p.currentUserID]) == 0 {
            p.currentSemesterID = try String.fetchOne(db, sql: "SELECT id FROM semesters WHERE user_id=? ORDER BY created_at,id LIMIT 1", arguments: [p.currentUserID])
        }
    }
    public func preferences() throws -> Preferences { try queue.read { try Self.preferences($0) } }
    public func revision() throws -> Int { try queue.read { try Int.fetchOne($0, sql: "SELECT value FROM app_metadata WHERE key='revision'") ?? 0 } }
    public func updatePreferences(_ preferences: Preferences) throws {
        try queue.write { db in
            var p = preferences; try Self.repairSelection(db, preferences: &p)
            if let asset = p.wallpaperAssetID, try Int.fetchOne(db, sql: "SELECT count(*) FROM assets WHERE id=?", arguments: [asset]) != 1 { throw StudyError.notFound }
            try Self.writePreferences(db,p); try Self.bump(db)
        }
    }
    public func users() throws -> [User] { try queue.read { try Row.fetchAll($0, sql: "SELECT * FROM users ORDER BY created_at,id").map(Self.user) } }
    public func semesters(userID: String) throws -> [Semester] {
        try queue.read { try Row.fetchAll($0, sql: "SELECT * FROM semesters WHERE user_id=? ORDER BY created_at,id", arguments: [userID]).map(Self.semester) }
    }
    public func subjects(scope: StudyScope) throws -> [Subject] {
        try queue.read { try Row.fetchAll($0, sql: "SELECT * FROM subjects WHERE user_id=? AND semester_id=? ORDER BY normalized_name,id", arguments: [scope.userID,scope.semesterID]).map(Self.subject) }
    }
    public func createUser(name: String, semester: String) throws -> StudyScope {
        let name = try Self.name(name), semester = try Self.name(semester)
        return try queue.write { db in
            let u = Self.id(), s = Self.id(), now = Self.now()
            try db.execute(sql: "INSERT INTO users VALUES(?,?,?,?,?)", arguments: [u,name,normalize(name),now,now])
            try db.execute(sql: "INSERT INTO semesters VALUES(?,?,?,?,?,?)", arguments: [s,u,semester,normalize(semester),now,now])
            var p = try Self.preferences(db); p.currentUserID = u; p.currentSemesterID = s
            try Self.writePreferences(db,p); try Self.bump(db)
            return StudyScope(userID: u,semesterID: s)
        }
    }
    public func saveSemester(id: String? = nil, name: String, userID: String) throws -> String {
        let name = try Self.name(name)
        return try queue.write { db in
            let key = id ?? Self.id(), now = Self.now()
            if id == nil {
                try db.execute(sql: "INSERT INTO semesters VALUES(?,?,?,?,?,?)", arguments: [key,userID,name,normalize(name),now,now])
            } else {
                try db.execute(sql: "UPDATE semesters SET name=?,normalized_name=?,updated_at=? WHERE id=? AND user_id=?", arguments: [name,normalize(name),now,key,userID])
                guard db.changesCount == 1 else { throw StudyError.notFound }
            }
            try Self.bump(db); return key
        }
    }
    public func renameUser(id: String, name: String) throws {
        let name = try Self.name(name)
        try queue.write { db in
            try db.execute(sql: "UPDATE users SET name=?,normalized_name=?,updated_at=? WHERE id=?", arguments: [name,normalize(name),Self.now(),id])
            guard db.changesCount == 1 else { throw StudyError.notFound }; try Self.bump(db)
        }
    }
    public func deleteUser(id: String) throws {
        try queue.write { db in
            guard try Int.fetchOne(db,sql: "SELECT count(*) FROM users")! > 1 else { throw StudyError.invalid("至少保留一个用户。") }
            try db.execute(sql: "DELETE FROM users WHERE id=?", arguments: [id])
            guard db.changesCount == 1 else { throw StudyError.notFound }
            var p = try Self.preferences(db); try Self.repairSelection(db,preferences: &p)
            try Self.writePreferences(db,p); try db.execute(sql: "DELETE FROM drafts"); try Self.bump(db)
        }
    }
    public func deleteSemester(id: String, userID: String) throws {
        try queue.write { db in
            let p = try Self.preferences(db)
            guard p.currentSemesterID != id else { throw StudyError.invalid("不能删除当前学期，请先切换。") }
            guard try Int.fetchOne(db,sql: "SELECT count(*) FROM subjects WHERE semester_id=? AND user_id=?",arguments: [id,userID]) == 0 else {
                throw StudyError.invalid("学期含有科目或成绩，请先清空。")
            }
            guard try Int.fetchOne(db,sql: "SELECT count(*) FROM semesters WHERE user_id=?",arguments: [userID])! > 1 else { throw StudyError.invalid("每位用户至少保留一个学期。") }
            try db.execute(sql: "DELETE FROM semesters WHERE id=? AND user_id=?",arguments: [id,userID]); try Self.bump(db)
        }
    }
    public func select(_ scope: StudyScope) throws {
        try queue.write { db in
            guard try Int.fetchOne(db,sql: "SELECT count(*) FROM semesters WHERE id=? AND user_id=?",arguments: [scope.semesterID,scope.userID]) == 1 else { throw StudyError.notFound }
            var p = try Self.preferences(db); p.currentUserID = scope.userID; p.currentSemesterID = scope.semesterID
            try Self.writePreferences(db,p); try Self.bump(db)
        }
    }
    public func saveSubject(id: String?, name: String, fullScore: Int64, scope: StudyScope) throws -> Subject {
        let name = try Self.name(name)
        guard fullScore > 0, fullScore <= Score.maximum else { throw StudyError.invalid("满分必须大于零。") }
        return try queue.write { db in
            let key = id ?? Self.id(), now = Self.now()
            if id == nil {
                try db.execute(sql: "INSERT INTO subjects VALUES(?,?,?,?,?,?,?,?)", arguments: [key,scope.userID,scope.semesterID,name,normalize(name),fullScore,now,now])
            } else {
                let maxScore = try Int64.fetchOne(db,sql: "SELECT MAX(score_minor) FROM exam_records WHERE subject_id=?", arguments: [key]) ?? 0
                guard fullScore >= maxScore else { throw StudyError.invalid("满分不能低于历史最高成绩 \(Score.text(maxScore))。") }
                try db.execute(sql: "UPDATE subjects SET name=?,normalized_name=?,full_score_minor=?,updated_at=? WHERE id=? AND user_id=? AND semester_id=?", arguments: [name,normalize(name),fullScore,now,key,scope.userID,scope.semesterID])
                guard db.changesCount == 1 else { throw StudyError.notFound }
            }
            try Self.bump(db)
            return Self.subject(try Row.fetchOne(db,sql: "SELECT * FROM subjects WHERE id=?",arguments: [key])!)
        }
    }
    public func deleteSubject(id: String, scope: StudyScope) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM subjects WHERE id=? AND user_id=? AND semester_id=?", arguments: [id,scope.userID,scope.semesterID])
            guard db.changesCount == 1 else { throw StudyError.notFound }; try Self.bump(db)
        }
    }
    public func saveExams(_ inputs: [ExamInput], scope: StudyScope) throws -> [Exam] {
        guard !inputs.isEmpty else { throw StudyError.invalid("至少录入一条成绩。") }
        return try queue.write { db in
            let result = try inputs.map { try Self.saveExam(db,$0,scope: scope) }; try Self.bump(db); return result
        }
    }
    static func saveExam(_ db: Database, _ input: ExamInput, scope: StudyScope, preserveEmptyName: Bool = false) throws -> Exam {
        guard let subject = try Row.fetchOne(db,sql: "SELECT * FROM subjects WHERE id=? AND user_id=? AND semester_id=?",arguments: [input.subjectID,scope.userID,scope.semesterID]) else { throw StudyError.notFound }
        let full: Int64 = subject["full_score_minor"]
        guard input.score >= 0, input.score <= full, input.score <= Score.maximum else { throw StudyError.invalid("分数须在 0 与满分之间。") }
        guard [input.classRank,input.gradeRank,input.districtRank].allSatisfy({ $0 == nil || $0! > 0 }) else { throw StudyError.invalid("排名须为正整数。") }
        let name = normalize(input.name).isEmpty && !preserveEmptyName ? input.type.label : normalize(input.name)
        guard name.count <= 100, (input.reflection?.count ?? 0) <= 10_000 else { throw StudyError.invalid("考试名称或反思超出长度限制。") }
        let key = input.id ?? Self.id(), now = Self.now()
        if input.id != nil {
            guard try Int.fetchOne(db,sql: "SELECT count(*) FROM exam_records WHERE id=? AND user_id=? AND semester_id=?",arguments: [key,scope.userID,scope.semesterID]) == 1 else { throw StudyError.notFound }
        }
        let duplicate = try Int.fetchOne(db,sql: "SELECT count(*) FROM exam_records WHERE user_id=? AND semester_id=? AND subject_id=? AND normalized_exam_name=? AND exam_date=? AND score_minor=? AND id<>?",arguments: [scope.userID,scope.semesterID,input.subjectID,normalize(name),input.date.description,input.score,key])!
        guard duplicate == 0 else { throw StudyError.duplicate }
        if input.id == nil {
            try db.execute(sql: "INSERT INTO exam_records(id,user_id,semester_id,subject_id,exam_name,normalized_exam_name,exam_date,score_minor,exam_type,class_rank,grade_rank,district_rank,reflection,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", arguments: [key,scope.userID,scope.semesterID,input.subjectID,name,normalize(name),input.date.description,input.score,input.type.rawValue,input.classRank,input.gradeRank,input.districtRank,input.reflection,now,now])
        } else {
            try db.execute(sql: "UPDATE exam_records SET subject_id=?,exam_name=?,normalized_exam_name=?,exam_date=?,score_minor=?,exam_type=?,class_rank=?,grade_rank=?,district_rank=?,reflection=?,updated_at=? WHERE id=? AND user_id=? AND semester_id=?", arguments: [input.subjectID,name,normalize(name),input.date.description,input.score,input.type.rawValue,input.classRank,input.gradeRank,input.districtRank,input.reflection,now,key,scope.userID,scope.semesterID])
        }
        return try Self.exam(Row.fetchOne(db,sql: "SELECT * FROM exam_records WHERE id=?",arguments: [key])!)
    }
    public func deleteExam(id: String, scope: StudyScope) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM exam_records WHERE id=? AND user_id=? AND semester_id=?",arguments: [id,scope.userID,scope.semesterID])
            guard db.changesCount == 1 else { throw StudyError.notFound }; try Self.bump(db)
        }
    }
    public func exams(scope: StudyScope, filter: ExamFilter, offset: Int = 0, limit: Int = 50) throws -> ExamPage {
        try queue.read { db in
            var clause = "e.user_id=? AND e.semester_id=?"
            var args: [any DatabaseValueConvertible] = [scope.userID,scope.semesterID]
            if let id = filter.subjectID { clause += " AND e.subject_id=?"; args.append(id) }
            if !filter.search.isEmpty {
                let escaped = filter.search.replacingOccurrences(of: "\\",with: "\\\\").replacingOccurrences(of: "%",with: "\\%").replacingOccurrences(of: "_",with: "\\_")
                clause += " AND e.exam_name LIKE ? ESCAPE '\\'"; args.append("%\(escaped)%")
            }
            let arguments = StatementArguments(args.map { $0.databaseValue })
            let stats = try Row.fetchOne(db,sql: "SELECT COUNT(*) n,SUM(e.score_minor) total,MIN(e.score_minor) minimum,MAX(e.score_minor) maximum,SUM(CASE WHEN e.score_minor*100>=s.full_score_minor*85 THEN 1 ELSE 0 END) excellent FROM exam_records e JOIN subjects s ON s.id=e.subject_id WHERE \(clause)",arguments: arguments)!
            let n: Int = stats["n"], excellent: Int = stats["excellent"] ?? 0
            let total: Int64 = stats["total"] ?? 0
            var exactAverage = n == 0 ? Decimal.zero : Decimal(total)/Decimal(n)/100
            var rounded = Decimal(); NSDecimalRound(&rounded,&exactAverage,1,.plain)
            let summary = ExamSummary(count: n,average: n == 0 ? nil : NSDecimalNumber(decimal: rounded).doubleValue,minimum: stats["minimum"],maximum: stats["maximum"],excellenceRate: n == 0 ? nil : excellent * 100 / n)
            let pageArgs = args.map { $0.databaseValue } + [max(1,min(limit,10001)).databaseValue,max(0,offset).databaseValue]
            let rows = try Row.fetchAll(db,sql: "SELECT e.* FROM exam_records e WHERE \(clause) ORDER BY e.exam_date DESC,e.created_at DESC,e.id DESC LIMIT ? OFFSET ?",arguments: StatementArguments(pageArgs)).map(Self.exam)
            return ExamPage(rows: rows,total: n,summary: summary)
        }
    }
    public func snapshot() throws -> Snapshot { try queue.read(Self.snapshot) }
    static func snapshot(_ db: Database) throws -> Snapshot {
        Snapshot(datasetID: try String.fetchOne(db,sql: "SELECT value FROM app_metadata WHERE key='dataset_id'")!,
                 users: try Row.fetchAll(db,sql: "SELECT * FROM users ORDER BY created_at,id").map(user),
                 semesters: try Row.fetchAll(db,sql: "SELECT * FROM semesters ORDER BY created_at,id").map(semester),
                 subjects: try Row.fetchAll(db,sql: "SELECT * FROM subjects ORDER BY id").map(subject),
                 exams: try Row.fetchAll(db,sql: "SELECT * FROM exam_records ORDER BY id").map(exam),
                 assets: try Row.fetchAll(db,sql: "SELECT * FROM assets ORDER BY id").map { Asset(id: $0["id"],relativePath: $0["relative_path"],mimeType: $0["mime_type"],sha256: $0["sha256"],byteCount: $0["byte_count"]) },
                 legacyIDMap: try Row.fetchAll(db,sql: "SELECT * FROM legacy_id_map ORDER BY source_dataset_id,entity_type,legacy_id").map { LegacyID(sourceDatasetID: $0["source_dataset_id"],entityType: $0["entity_type"],legacyID: $0["legacy_id"],canonicalID: $0["canonical_id"]) },preferences: try preferences(db))
    }
    static func insertSnapshot(_ db: Database, _ s: Snapshot) throws {
        for x in s.users { try db.execute(sql: "INSERT INTO users VALUES(?,?,?,?,?)",arguments: [x.id,try name(x.name),normalize(x.name),x.createdAt,x.updatedAt]) }
        for x in s.semesters { try db.execute(sql: "INSERT INTO semesters VALUES(?,?,?,?,?,?)",arguments: [x.id,x.userID,try name(x.name),normalize(x.name),x.createdAt,x.updatedAt]) }
        for x in s.subjects { try db.execute(sql: "INSERT INTO subjects VALUES(?,?,?,?,?,?,?,?)",arguments: [x.id,x.userID,x.semesterID,try name(x.name),normalize(x.name),x.fullScore,x.createdAt,x.updatedAt]) }
        for x in s.assets { try db.execute(sql: "INSERT INTO assets VALUES(?,?,?,?,?)",arguments: [x.id,x.relativePath,x.mimeType,x.sha256,x.byteCount]) }
        for x in s.exams {
            guard x.name.count <= 100, (x.reflection?.count ?? 0) <= 10_000 else { throw StudyError.corrupt("名称/反思超出长度限制。") }
            try db.execute(sql: "INSERT INTO exam_records VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",arguments: [x.id,x.userID,x.semesterID,x.subjectID,x.name,normalize(x.name),x.date.description,x.score,x.type.rawValue,x.classRank,x.gradeRank,x.districtRank,x.reflection,x.attachmentID,x.createdAt,x.updatedAt])
        }
        for x in s.legacyIDMap { try db.execute(sql: "INSERT INTO legacy_id_map VALUES(?,?,?,?)",arguments: [x.sourceDatasetID,x.entityType,x.legacyID,x.canonicalID]) }
    }
    public static func validateSnapshot(_ s: Snapshot) throws {
        guard !s.users.isEmpty, s.preferences.nameNormalizationVersion == 1,
              ["simple","glass"].contains(s.preferences.theme), ["blue","green","orange","purple"].contains(s.preferences.accent),
              s.users.allSatisfy({ u in s.semesters.contains { $0.userID == u.id } }) else { throw StudyError.corrupt("用户、学期或设置无效。") }
        let ids = s.users.map(\.id) + s.semesters.map(\.id) + s.subjects.map(\.id) + s.exams.map(\.id) + s.assets.map(\.id) + [s.datasetID]
        guard ids.allSatisfy({ UUID(uuidString: $0) != nil && $0 == $0.lowercased() }) else { throw StudyError.corrupt("备份主键须为小写 UUID。") }
        for date in s.users.flatMap({ [$0.createdAt,$0.updatedAt] }) + s.semesters.flatMap({ [$0.createdAt,$0.updatedAt] }) + s.subjects.flatMap({ [$0.createdAt,$0.updatedAt] }) + s.exams.flatMap({ [$0.createdAt,$0.updatedAt] }) {
            guard validTimestamp(date) else { throw StudyError.corrupt("创建/修改时间必须是 RFC3339。") }
        }
        if let id = s.preferences.wallpaperAssetID, !s.assets.contains(where: { $0.id == id }) { throw StudyError.corrupt("壁纸引用不存在。") }
        for item in s.legacyIDMap {
            let target: Set<String>
            switch item.entityType { case "user": target = Set(s.users.map(\.id)); case "semester": target = Set(s.semesters.map(\.id)); case "subject": target = Set(s.subjects.map(\.id)); case "exam": target = Set(s.exams.map(\.id)); default: throw StudyError.corrupt("未知旧 ID 类型。") }
            guard target.contains(item.canonicalID), UUID(uuidString: item.sourceDatasetID) != nil else { throw StudyError.corrupt("旧 ID 映射无效。") }
        }
        var config = Configuration(); config.foreignKeysEnabled = true
        let q = try DatabaseQueue(configuration: config)
        try q.write { db in
            try db.execute(sql: String(contentsOf: Bundle.module.url(forResource: "schema",withExtension: "sql")!,encoding: .utf8))
            try insertSnapshot(db,s)
        }
    }
    public func restore(_ snapshot: Snapshot, backupID: String = UUID().uuidString.lowercased(), expectedRevision: Int? = nil) throws {
        try Self.validateSnapshot(snapshot)
        try queue.write { db in
            if let expectedRevision, try Int.fetchOne(db,sql: "SELECT value FROM app_metadata WHERE key='revision'") != expectedRevision { throw StudyError.scopeChanged }
            try db.execute(sql: "DELETE FROM users; DELETE FROM assets; DELETE FROM legacy_id_map; DELETE FROM drafts;")
            try Self.insertSnapshot(db,snapshot)
            var p = snapshot.preferences; try Self.repairSelection(db,preferences: &p); try Self.writePreferences(db,p)
            try db.execute(sql: "UPDATE app_metadata SET value=? WHERE key='dataset_id'",arguments: [snapshot.datasetID])
            try db.execute(sql: "INSERT INTO restore_operations VALUES(?,?,?,?,?)",arguments: [Self.id(),backupID,"dbCommitted",try Self.json(p),Self.now()])
            try Self.bump(db)
        }
        try queue.write { try $0.execute(sql: "UPDATE restore_operations SET phase='completed' WHERE phase='dbCommitted'") }
    }
    public static func validTimestamp(_ date: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        if formatter.date(from: date) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        return formatter.date(from: date) != nil
    }
    public func addAsset(_ asset: Asset) throws -> Asset {
        try queue.write { db in
            if let existing = try Row.fetchOne(db,sql: "SELECT * FROM assets WHERE relative_path=?",arguments: [asset.relativePath]) {
                guard existing["sha256"] as String == asset.sha256 else { throw StudyError.corrupt("资源内容冲突。") }
                return Asset(id: existing["id"],relativePath: existing["relative_path"],mimeType: existing["mime_type"],sha256: existing["sha256"],byteCount: existing["byte_count"])
            }
            try db.execute(sql: "INSERT INTO assets VALUES(?,?,?,?,?)",arguments: [asset.id,asset.relativePath,asset.mimeType,asset.sha256,asset.byteCount]); try Self.bump(db)
            return asset
        }
    }
    public func draft(key: String) throws -> Data? { try queue.read { try Data.fetchOne($0,sql: "SELECT payload FROM drafts WHERE key=?",arguments: [key]) } }
    public func setDraft(key: String, data: Data?) throws {
        try queue.write { db in
            if let data { try db.execute(sql: "INSERT INTO drafts VALUES(?,?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload",arguments: [key,data]) }
            else { try db.execute(sql: "DELETE FROM drafts WHERE key=?",arguments: [key]) }
        }
    }
    static func user(_ r: Row) -> User { User(id: r["id"],name: r["name"],createdAt: r["created_at"],updatedAt: r["updated_at"]) }
    static func semester(_ r: Row) -> Semester { Semester(id: r["id"],userID: r["user_id"],name: r["name"],createdAt: r["created_at"],updatedAt: r["updated_at"]) }
    static func subject(_ r: Row) -> Subject { Subject(id: r["id"],userID: r["user_id"],semesterID: r["semester_id"],name: r["name"],fullScore: r["full_score_minor"],createdAt: r["created_at"],updatedAt: r["updated_at"]) }
    static func exam(_ r: Row) throws -> Exam {
        guard let type = ExamType(rawValue: r["exam_type"]) else { throw StudyError.corrupt("未知考试分类。") }
        return Exam(id: r["id"],userID: r["user_id"],semesterID: r["semester_id"],subjectID: r["subject_id"],name: r["exam_name"],date: try LocalDate(r["exam_date"]),score: r["score_minor"],type: type,classRank: r["class_rank"],gradeRank: r["grade_rank"],districtRank: r["district_rank"],reflection: r["reflection"],attachmentID: r["attachment_id"],createdAt: r["created_at"],updatedAt: r["updated_at"])
    }
}
