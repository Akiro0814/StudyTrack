import Foundation
import GRDB

public struct ImportPlan: Sendable, Identifiable {
    public let id: UUID; public let scope: StudyScope; public let revision: Int; public let fileDigest: String
    public let rows: [ExchangeRow]; public let issues: [ImportIssue]; public let duplicates: Int; public let conflicts: Int
    public let newSemesters: [String]; public let newSubjects: [String]
}
public struct ImportReport: Codable, Sendable {
    public var imported: Int; public var duplicates: Int; public var conflicts: Int; public var issues: [ImportIssue]
}
extension StudyStore {
    public func previewImport(_ parsed: ParsedWorkbook, scope: StudyScope, fileDigest: String) throws -> ImportPlan {
        try queue.read { db in
            let revision = try Int.fetchOne(db,sql: "SELECT value FROM app_metadata WHERE key='revision'") ?? 0
            guard try Int.fetchOne(db,sql: "SELECT count(*) FROM semesters WHERE id=? AND user_id=?",arguments: [scope.semesterID,scope.userID]) == 1 else { throw StudyError.notFound }
            let defaultName = try String.fetchOne(db,sql: "SELECT name FROM semesters WHERE id=?",arguments: [scope.semesterID])!
            var semesters: [String: String] = [:], subjects: [String: (String,Int64)] = [:]
            for r in try Row.fetchAll(db,sql: "SELECT * FROM semesters WHERE user_id=?",arguments: [scope.userID]) {
                semesters[r["normalized_name"]] = r["id"]
                if let term = try Self.readSemester(db,r).schoolTerm { semesters[term.label] = r["id"] }
            }
            for r in try Row.fetchAll(db,sql: "SELECT * FROM subjects WHERE user_id=?",arguments: [scope.userID]) { subjects["\(r["semester_id"] as String)\u{0}\(r["normalized_name"] as String)"] = (r["id"],r["full_score_minor"]) }
            var rows: [ExchangeRow] = [], issues = parsed.issues, seen: [String: ExchangeRow] = [:]
            var duplicates = 0, conflicts = 0, newSemesters = Set<String>(), newSubjects = Set<String>()
            for original in parsed.rows {
                var row = original
                let originalTerm = row.semester.isEmpty ? defaultName : normalize(row.semester)
                let semesterName = SchoolTerm.recognize(originalTerm)?.label ?? originalTerm
                guard semesterName.count <= 100, row.subject.count <= 100 else { issues.append(.init(row: row.row,reason: "学期或科目名称过长。")); continue }
                row.semester = semesterName
                let createsSemester = semesters[semesterName] == nil
                let semesterID = semesters[semesterName] ?? Self.id()
                let subjectKey = semesterID + "\u{0}" + normalize(row.subject)
                let createsSubject = subjects[subjectKey] == nil
                let subject = subjects[subjectKey] ?? (Self.id(),row.fullScore ?? 10000)
                guard row.fullScore == nil || row.fullScore == subject.1 else { issues.append(.init(row: row.row,reason: "科目满分冲突，请修改源文件或现有科目。")); continue }
                row.fullScore = subject.1
                guard row.score <= subject.1 else { issues.append(.init(row: row.row,reason: "分数超过科目满分。")); continue }
                let key = [semesterID,subject.0,normalize(row.name),row.date.description,String(row.score)].joined(separator: "\u{0}")
                var isDuplicate = false, contentConflict = false
                if let previous = seen[key] {
                    isDuplicate = true; contentConflict = !Self.sameContent(previous,row)
                } else if let existing = try Row.fetchOne(db,sql: "SELECT * FROM exam_records WHERE user_id=? AND semester_id=? AND subject_id=? AND normalized_exam_name=? AND exam_date=? AND score_minor=?",arguments: [scope.userID,semesterID,subject.0,normalize(row.name),row.date.description,row.score]) {
                    let exam = try Self.exam(existing); isDuplicate = true
                    contentConflict = exam.type != row.type || exam.classRank != row.classRank || exam.gradeRank != row.gradeRank || exam.districtRank != row.districtRank || exam.reflection != row.reflection
                }
                if isDuplicate {
                    if contentConflict { conflicts += 1; issues.append(.init(row: row.row,reason: "去重键相同但排名、分类或备注不同，保留已有记录。",warning: true)) }
                    else { duplicates += 1; issues.append(.init(row: row.row,reason: "重复成绩，跳过。",warning: true)) }
                    continue
                }
                // Only accepted rows may influence later planning or creation counts.
                semesters[semesterName] = semesterID; subjects[subjectKey] = subject
                if createsSemester { newSemesters.insert(semesterName) }
                if createsSubject { newSubjects.insert("\(semesterName) / \(row.subject)") }
                seen[key] = row; rows.append(row)
            }
            return ImportPlan(id: UUID(),scope: scope,revision: revision,fileDigest: fileDigest,rows: rows,issues: issues,duplicates: duplicates,conflicts: conflicts,newSemesters: newSemesters.sorted(),newSubjects: newSubjects.sorted())
        }
    }
    static func sameContent(_ a: ExchangeRow, _ b: ExchangeRow) -> Bool {
        a.type == b.type && a.classRank == b.classRank && a.gradeRank == b.gradeRank && a.districtRank == b.districtRank && a.reflection == b.reflection
    }
    public func commitImport(_ plan: ImportPlan, validRowsOnly: Bool, acceptConversions: Bool) throws -> ImportReport {
        guard validRowsOnly || !plan.issues.contains(where: { !$0.warning }) else { throw StudyError.invalid("存在错误行，请修正或明确选择仅导入有效行。") }
        guard acceptConversions || !plan.issues.contains(where: { $0.warning && ($0.reason.contains("只保留日期") || $0.reason.contains("未知分类")) }) else { throw StudyError.invalid("请确认日期/分类转换。") }
        return try queue.write { db in
            guard try Int.fetchOne(db,sql: "SELECT value FROM app_metadata WHERE key='revision'") == plan.revision,
                  try Self.preferences(db).scope == plan.scope else { throw StudyError.scopeChanged }
            for row in plan.rows {
                let semesterID: String
                if let id = try Self.semesterID(db,userID: plan.scope.userID,name: row.semester) { semesterID = id }
                else {
                    semesterID = Self.id(); let now = Self.now()
                    try db.execute(sql: "INSERT INTO semesters VALUES(?,?,?,?,?,?)",arguments: [semesterID,plan.scope.userID,row.semester,normalize(row.semester),now,now])
                    if let term = SchoolTerm.recognize(row.semester) { try Self.setTerm(db,semesterID: semesterID,userID: plan.scope.userID,term: term) }
                }
                let subjectID: String
                if let id = try String.fetchOne(db,sql: "SELECT id FROM subjects WHERE user_id=? AND semester_id=? AND normalized_name=?",arguments: [plan.scope.userID,semesterID,normalize(row.subject)]) { subjectID = id }
                else {
                    subjectID = Self.id(); let now = Self.now()
                    try db.execute(sql: "INSERT INTO subjects VALUES(?,?,?,?,?,?,?,?)",arguments: [subjectID,plan.scope.userID,semesterID,row.subject,normalize(row.subject),row.fullScore ?? 10000,now,now])
                    _ = try Self.lineage(db,subjectID: subjectID,userID: plan.scope.userID,semesterID: semesterID,name: row.subject)
                }
                _ = try Self.saveExam(db,ExamInput(subjectID: subjectID,name: row.name,date: row.date,score: row.score,type: row.type,classRank: row.classRank,gradeRank: row.gradeRank,districtRank: row.districtRank,reflection: row.reflection),scope: StudyScope(userID: plan.scope.userID,semesterID: semesterID),preserveEmptyName: true)
            }
            try Self.bump(db)
            return ImportReport(imported: plan.rows.count,duplicates: plan.duplicates,conflicts: plan.conflicts,issues: plan.issues)
        }
    }
    public func exportRows(scope: StudyScope) throws -> [ExchangeRow] {
        try queue.read { db in
            let rows = try Row.fetchAll(db,sql: "SELECT e.*,s.name subject_name,s.full_score_minor,t.name semester_name FROM exam_records e JOIN subjects s ON s.id=e.subject_id JOIN semesters t ON t.id=e.semester_id WHERE e.user_id=? AND e.semester_id=? ORDER BY e.exam_date DESC,e.created_at DESC,e.id DESC",arguments: [scope.userID,scope.semesterID])
            return try rows.enumerated().map { i,r in
                let e = try Self.exam(r)
                return ExchangeRow(row: i+2,semester: r["semester_name"],subject: r["subject_name"],name: e.name,date: e.date,score: e.score,fullScore: r["full_score_minor"],type: e.type,classRank: e.classRank,gradeRank: e.gradeRank,districtRank: e.districtRank,reflection: e.reflection)
            }
        }
    }
}
