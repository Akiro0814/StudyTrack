import Foundation
import GRDB

extension StudyStore {
    static func semesterID(_ db: Database,userID: String,name: String) throws -> String? {
        if let id = try String.fetchOne(db,sql: "SELECT id FROM semesters WHERE user_id=? AND normalized_name=?",arguments: [userID,normalize(name)]) { return id }
        guard let term = SchoolTerm.recognize(name) else { return nil }
        return try String.fetchOne(db,sql: "SELECT semester_id FROM semester_school WHERE user_id=? AND stage=? AND year=? AND half=?",arguments: [userID,term.stage.rawValue,term.year,term.half])
    }
    public func restoreExam(_ exam: Exam) throws {
        try queue.write { db in
            guard try Self.preferences(db).currentUserID == exam.userID else { throw StudyError.scopeChanged }
            try db.execute(sql: "INSERT INTO exam_records VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",arguments: [exam.id,exam.userID,exam.semesterID,exam.subjectID,exam.name,normalize(exam.name),exam.date.description,exam.score,exam.type.rawValue,exam.classRank,exam.gradeRank,exam.districtRank,exam.reflection,exam.attachmentID,exam.createdAt,exam.updatedAt])
            try Self.bump(db)
        }
    }
    static let schoolSchema = """
    CREATE TABLE IF NOT EXISTS semester_school (semester_id TEXT PRIMARY KEY REFERENCES semesters(id) ON DELETE CASCADE, user_id TEXT NOT NULL, stage TEXT NOT NULL, year INTEGER NOT NULL, half INTEGER NOT NULL, UNIQUE(user_id,stage,year,half));
    CREATE TABLE IF NOT EXISTS subject_lineage (subject_id TEXT PRIMARY KEY REFERENCES subjects(id) ON DELETE CASCADE, lineage_id TEXT NOT NULL);
    """
    static func readSemester(_ db: Database, _ row: Row) throws -> Semester {
        var result = semester(row)
        if let meta = try Row.fetchOne(db, sql: "SELECT * FROM semester_school WHERE semester_id=?", arguments: [result.id]), let stage = SchoolStage(rawValue: meta["stage"]) {
            result.schoolTerm = SchoolTerm(stage: stage, year: meta["year"], half: meta["half"])
        }
        return result
    }
    static func readSubject(_ db: Database, _ row: Row) throws -> Subject {
        var result = subject(row)
        result.lineageID = try String.fetchOne(db, sql: "SELECT lineage_id FROM subject_lineage WHERE subject_id=?", arguments: [result.id])
        return result
    }
    static func setTerm(_ db: Database, semesterID: String, userID: String, term: SchoolTerm) throws {
        guard term.valid else { throw StudyError.invalid("请选择有效学期。") }
        guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM semester_school WHERE user_id=? AND stage=? AND year=? AND half=? AND semester_id<>?", arguments: [userID,term.stage.rawValue,term.year,term.half,semesterID]) == 0 else { throw StudyError.duplicate }
        try db.execute(sql: "INSERT INTO semester_school VALUES(?,?,?,?,?) ON CONFLICT(semester_id) DO UPDATE SET stage=excluded.stage,year=excluded.year,half=excluded.half", arguments: [semesterID,userID,term.stage.rawValue,term.year,term.half])
    }
    static func lineage(_ db: Database, subjectID: String, userID: String, semesterID: String, name: String) throws -> String {
        if let existing = try String.fetchOne(db, sql: "SELECT lineage_id FROM subject_lineage WHERE subject_id=?", arguments: [subjectID]) { return existing }
        let related = try String.fetchOne(db, sql: "SELECT l.lineage_id FROM subjects s JOIN subject_lineage l ON l.subject_id=s.id JOIN semester_school t ON t.semester_id=s.semester_id JOIN semester_school current ON current.semester_id=? WHERE s.user_id=? AND s.normalized_name=? AND t.stage=current.stage ORDER BY t.year,t.half LIMIT 1", arguments: [semesterID,userID,normalize(name)])
        let id = related ?? Self.id()
        try db.execute(sql: "INSERT INTO subject_lineage VALUES(?,?)", arguments: [subjectID,id])
        return id
    }
    public func createProfile(name: String, term: SchoolTerm, avatar: Asset?) throws -> StudyScope {
        let name = try Self.name(name)
        guard term.valid else { throw StudyError.invalid("请选择有效学期。") }
        return try queue.write { db in
            var p = try Self.preferences(db)
            guard try p.multiUserEnabled || Int.fetchOne(db, sql: "SELECT COUNT(*) FROM users") == 0 else { throw StudyError.invalid("请先开启多用户模式。") }
            let user = Self.id(), semester = Self.id(), now = Self.now()
            try db.execute(sql: "INSERT INTO users VALUES(?,?,?,?,?)", arguments: [user,name,normalize(name),now,now])
            try db.execute(sql: "INSERT INTO semesters VALUES(?,?,?,?,?,?)", arguments: [semester,user,term.label,normalize(term.label),now,now])
            try Self.setTerm(db, semesterID: semester, userID: user, term: term)
            if let avatar {
                let existing = try String.fetchOne(db, sql: "SELECT id FROM assets WHERE relative_path=? AND sha256=?", arguments: [avatar.relativePath,avatar.sha256])
                if existing == nil { try db.execute(sql: "INSERT INTO assets VALUES(?,?,?,?,?)", arguments: [avatar.id,avatar.relativePath,avatar.mimeType,avatar.sha256,avatar.byteCount]) }
                p.setAvatarAssetID(existing ?? avatar.id, for: user)
            }
            p.currentUserID = user; p.currentSemesterID = semester
            try Self.writePreferences(db,p); try Self.bump(db)
            return StudyScope(userID: user, semesterID: semester)
        }
    }
    public func saveSchoolSemester(id: String? = nil, term: SchoolTerm, userID: String) throws -> String {
        guard term.valid else { throw StudyError.invalid("请选择有效学期。") }
        return try queue.write { db in
            let key = id ?? Self.id(), now = Self.now()
            guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM semesters WHERE user_id=? AND normalized_name=? AND id<>?", arguments: [userID,normalize(term.label),key]) == 0 else { throw StudyError.duplicate }
            if id == nil {
                try db.execute(sql: "INSERT INTO semesters VALUES(?,?,?,?,?,?)", arguments: [key,userID,term.label,normalize(term.label),now,now])
            } else {
                guard try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM semester_school WHERE semester_id=?", arguments: [key]) == 0 else { throw StudyError.invalid("已归类学期不能更换阶段，请新建学期。") }
                try db.execute(sql: "UPDATE semesters SET name=?,normalized_name=?,updated_at=? WHERE id=? AND user_id=?", arguments: [term.label,normalize(term.label),now,key,userID])
                guard db.changesCount == 1 else { throw StudyError.notFound }
            }
            try Self.setTerm(db, semesterID: key, userID: userID, term: term)
            if id == nil {
                let candidates = try Row.fetchAll(db, sql: "SELECT * FROM semester_school WHERE user_id=? AND stage=? AND semester_id<>?", arguments: [userID,term.stage.rawValue,key])
                let source = candidates.sorted { a,b in
                    let ao = (a["year"] as Int)*2 + (a["half"] as Int), bo = (b["year"] as Int)*2 + (b["half"] as Int)
                    if (ao < term.order) != (bo < term.order) { return ao < term.order }
                    return abs(ao-term.order) < abs(bo-term.order)
                }.first
                if let source {
                    for row in try Row.fetchAll(db, sql: "SELECT * FROM subjects WHERE semester_id=? AND user_id=?", arguments: [source["semester_id"] as String,userID]) {
                        let subjectID = Self.id(), sourceID: String = row["id"], name: String = row["name"]
                        let lineage = try Self.lineage(db,subjectID: sourceID,userID: userID,semesterID: source["semester_id"],name: name)
                        try db.execute(sql: "INSERT INTO subjects VALUES(?,?,?,?,?,?,?,?)", arguments: [subjectID,userID,key,name,normalize(name),row["full_score_minor"] as Int64,now,now])
                        try db.execute(sql: "INSERT INTO subject_lineage VALUES(?,?)", arguments: [subjectID,lineage])
                    }
                }
            }
            try Self.bump(db); return key
        }
    }
    public func analysis(scope: StudyScope, wholeStage: Bool) throws -> AnalysisData {
        try queue.read { db in
            var clause = "s.user_id=? AND s.semester_id=?"
            var args: [String] = [scope.userID,scope.semesterID]
            if wholeStage {
                guard let stage = try String.fetchOne(db, sql: "SELECT stage FROM semester_school WHERE semester_id=? AND user_id=?", arguments: [scope.semesterID,scope.userID]) else { throw StudyError.invalid("请先将当前学期归类到学习阶段。") }
                clause = "s.user_id=? AND s.semester_id IN (SELECT semester_id FROM semester_school WHERE user_id=? AND stage=?)"; args = [scope.userID,scope.userID,stage]
            }
            let arguments = StatementArguments(args)
            let subjectRows = try Row.fetchAll(db, sql: "SELECT s.* FROM subjects s WHERE \(clause) ORDER BY normalized_name,id", arguments: arguments)
            let subjects: [Subject] = try subjectRows.map { try Self.readSubject(db,$0) }
            let examRows = try Row.fetchAll(db, sql: "SELECT e.* FROM exam_records e JOIN subjects s ON s.id=e.subject_id WHERE \(clause) ORDER BY e.exam_date,e.created_at,e.id", arguments: arguments)
            let exams: [Exam] = try examRows.map { try Self.exam($0) }
            let grouped: [String: [Subject]] = Dictionary(grouping: subjects) { subject in "\(subject.lineageID ?? subject.id)|\(subject.fullScore)" }
            var groups: [AnalysisGroup] = []
            for (key,values) in grouped {
                let ids: Set<String> = Set(values.map { $0.id })
                let records: [Exam] = exams.filter { ids.contains($0.subjectID) }
                groups.append(AnalysisGroup(id: key,subject: values[0],exams: records))
            }
            groups.sort { lhs,rhs in
                if lhs.subject.name == rhs.subject.name { return lhs.subject.fullScore < rhs.subject.fullScore }
                return lhs.subject.name < rhs.subject.name
            }
            return AnalysisData(subjects: subjects, exams: exams, groups: groups)
        }
    }
}
