import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct ExchangeRow: Codable, Sendable {
    public var row: Int; public var semester: String; public var subject: String; public var name: String; public var date: LocalDate
    public var score: Int64; public var fullScore: Int64?; public var type: ExamType
    public var classRank: Int?; public var gradeRank: Int?; public var districtRank: Int?; public var reflection: String?
    public init(row: Int, semester: String, subject: String, name: String, date: LocalDate, score: Int64, fullScore: Int64?, type: ExamType, classRank: Int?, gradeRank: Int?, districtRank: Int?, reflection: String?) {
        self.row = row; self.semester = semester; self.subject = subject; self.name = name; self.date = date; self.score = score
        self.fullScore = fullScore; self.type = type; self.classRank = classRank; self.gradeRank = gradeRank; self.districtRank = districtRank; self.reflection = reflection
    }
}
public struct ImportIssue: Codable, Identifiable, Sendable {
    public var id: String { "\(row)-\(reason)" }; public var row: Int; public var reason: String; public var warning: Bool
    public init(row: Int, reason: String, warning: Bool = false) { self.row = row; self.reason = reason; self.warning = warning }
}
public struct ParsedWorkbook: Sendable { public var rows: [ExchangeRow]; public var issues: [ImportIssue] }

private final class XMLNode {
    let name: String; let attributes: [String: String]; var text = ""; var children: [XMLNode] = []
    init(_ name: String, _ attributes: [String: String]) { self.name = name; self.attributes = attributes }
    func all(_ name: String) -> [XMLNode] { children.flatMap { ($0.name == name ? [$0] : []) + $0.all(name) } }
    func first(_ name: String) -> XMLNode? { all(name).first }
}
private final class XMLTree: NSObject, XMLParserDelegate {
    var root: XMLNode?; var stack: [XMLNode] = []; var count = 0
    static func parse(_ data: Data) throws -> XMLNode {
        guard data.count <= 80*1024*1024,
              let text = String(data: data,encoding: .utf8), !text.localizedCaseInsensitiveContains("<!DOCTYPE"),
              !text.localizedCaseInsensitiveContains("<!ENTITY") else { throw StudyError.corrupt("XML 过大或包含不支持的实体。") }
        let delegate = XMLTree(), parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), let root = delegate.root else { throw StudyError.corrupt("Excel XML 结构损坏。") }; return root
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        count += 1
        guard count <= 1_000_000, stack.count < 64 else { parser.abortParsing(); return }
        let node = XMLNode(elementName,attributeDict)
        if let parent = stack.last { parent.children.append(node) } else { root = node }; stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { _ = stack.popLast() }
}

public enum XLSXCodec {
    public static let headers = ["学期","科目","考试名称","时间","分数","满分","分类","班排","年排","区排","反思"]
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&",with: "&amp;").replacingOccurrences(of: "<",with: "&lt;").replacingOccurrences(of: ">",with: "&gt;").replacingOccurrences(of: "\"",with: "&quot;")
    }
    public static func encode(_ rows: [ExchangeRow]) throws -> Data {
        func stringCell(_ column: Int, _ row: Int, _ value: String) -> String {
            "<c r=\"\(Character(UnicodeScalar(65+column)!))\(row)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
        }
        func numberCell(_ column: Int, _ row: Int, _ value: String?) -> String {
            guard let value else { return "" }; return "<c r=\"\(Character(UnicodeScalar(65+column)!))\(row)\"><v>\(value)</v></c>"
        }
        var sheet = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData><row r=\"1\">"
        sheet += headers.enumerated().map { stringCell($0.offset,1,$0.element) }.joined() + "</row>"
        for (i,x) in rows.enumerated() {
            let row = i+2
            sheet += "<row r=\"\(row)\">" + stringCell(0,row,x.semester) + stringCell(1,row,x.subject) + stringCell(2,row,x.name) + stringCell(3,row,x.date.description)
            sheet += numberCell(4,row,Score.fixed(x.score)) + numberCell(5,row,x.fullScore.map(Score.fixed)) + stringCell(6,row,x.type.label)
            sheet += numberCell(7,row,x.classRank.map(String.init)) + numberCell(8,row,x.gradeRank.map(String.init)) + numberCell(9,row,x.districtRank.map(String.init))
            sheet += stringCell(10,row,x.reflection ?? "") + "</row>"
        }
        sheet += "</sheetData></worksheet>"
        let files = [
            "[Content_Types].xml": "<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
            "_rels/.rels": "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
            "xl/workbook.xml": "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Grades\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
            "xl/_rels/workbook.xml.rels": "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
            "xl/worksheets/sheet1.xml": sheet
        ]
        return try SafeArchive.write(files.mapValues { Data($0.utf8) })
    }
    public static func decode(_ data: Data) throws -> ParsedWorkbook {
        let files = try SafeArchive.read(data,compressedLimit: 20*1024*1024,expandedLimit: 200*1024*1024)
        guard let workbookData = files["xl/workbook.xml"], let relData = files["xl/_rels/workbook.xml.rels"] else { throw StudyError.unsupported("需要普通未加密 .xlsx 文件；不支持旧 .xls、宏或加密文件。") }
        guard !files.keys.contains(where: { $0.lowercased().hasSuffix("vbaproject.bin") }) else { throw StudyError.unsupported("不支持宏工作簿。") }
        let workbook = try XMLTree.parse(workbookData), rels = try XMLTree.parse(relData)
        let system1904 = ["1","true"].contains(workbook.first("workbookPr")?.attributes["date1904"] ?? "0")
        guard let sheet = workbook.first("sheet"), let relationID = sheet.attributes["r:id"] ?? sheet.attributes["id"],
              let relation = rels.all("Relationship").first(where: { $0.attributes["Id"] == relationID }),
              relation.attributes["TargetMode"] != "External", let target = relation.attributes["Target"] else { throw StudyError.corrupt("找不到第一个工作表。") }
        let sheetPath = target.hasPrefix("/xl/") ? String(target.dropFirst()) : "xl/" + target
        try SafeArchive.validatePath(sheetPath)
        guard let sheetData = files[sheetPath] else { throw StudyError.corrupt("工作表文件缺失。") }
        let root = try XMLTree.parse(sheetData)
        let strings: [String]
        if let shared = files["xl/sharedStrings.xml"] { strings = try XMLTree.parse(shared).all("si").map { $0.all("t").map(\.text).joined() } } else { strings = [] }
        var dateStyles = Set<Int>()
        if let styleData = files["xl/styles.xml"] {
            let styles = try XMLTree.parse(styleData)
            var formats: [Int: String] = [:]
            for x in styles.all("numFmt") {
                guard let id = Int(x.attributes["numFmtId"] ?? ""), formats[id] == nil else { throw StudyError.corrupt("日期样式索引重复或无效。") }
                formats[id] = x.attributes["formatCode"] ?? ""
            }
            for (index,xf) in (styles.first("cellXfs")?.children ?? []).enumerated() {
                let id = Int(xf.attributes["numFmtId"] ?? "0") ?? 0
                let format = (formats[id] ?? "").lowercased().replacingOccurrences(of: #"\"[^\"]*\"|\[[^\]]*\]|\\."#,with: "",options: .regularExpression)
                if (14...22).contains(id) || (27...36).contains(id) || (50...58).contains(id) || (format.contains("y") && format.contains("d")) { dateStyles.insert(index) }
            }
        }
        func cellString(_ cell: XMLNode) throws -> String {
            if cell.first("f") != nil { throw StudyError.invalid("不支持公式单元格，请粘贴为值。") }
            let type = cell.attributes["t"] ?? "n", raw = cell.first("v")?.text ?? ""
            if type == "s" {
                guard let index = Int(raw), strings.indices.contains(index) else { throw StudyError.corrupt("共享字符串索引损坏。") }; return strings[index]
            }
            if type == "inlineStr" { return cell.all("t").map(\.text).joined() }
            if type == "e" || type == "b" { throw StudyError.invalid("单元格为错误或布尔值。") }
            return raw
        }
        func columns(_ row: XMLNode) throws -> [String: XMLNode] {
            var map: [String: XMLNode] = [:]
            for cell in row.children where cell.name == "c" {
                guard let reference = cell.attributes["r"], reference.range(of: #"^[A-Z]+[1-9][0-9]*$"#,options: .regularExpression) != nil else { throw StudyError.corrupt("单元格缺少有效 reference。") }
                let column = String(reference.prefix(while: { $0.isLetter }))
                guard map[column] == nil else { throw StudyError.corrupt("工作表包含重复单元格。") }; map[column] = cell
            }
            return map
        }
        let sheetRows = root.first("sheetData")?.children.filter { $0.name == "row" } ?? []
        guard let header = sheetRows.first, header.attributes["r"] == "1" else { throw StudyError.corrupt("第一行必须为表头。") }
        if root.all("mergeCell").contains(where: { ($0.attributes["ref"] ?? "").split(separator: ":").contains { $0.hasSuffix("1") && !$0.hasSuffix("11") } }) { throw StudyError.corrupt("表头不支持合并单元格。") }
        var titles: [String: String] = [:]
        for (column,cell) in try columns(header) {
            let title = normalize(try cellString(cell)); if title.isEmpty { continue }
            guard titles[title] == nil else { throw StudyError.corrupt("存在重复表头：\(title)") }; titles[title] = column
        }
        guard ["科目","时间","分数"].allSatisfy({ titles[$0] != nil }) else { throw StudyError.corrupt("缺少必填列：科目、时间、分数。") }
        guard sheetRows.count <= 10001 else { throw StudyError.invalid("Excel 最多支持 10000 行。") }
        var rows: [ExchangeRow] = [], issues: [ImportIssue] = []
        var seenRowNumbers = Set<Int>([1])
        for (index,row) in sheetRows.dropFirst().enumerated() {
            let rowNumber = Int(row.attributes["r"] ?? "") ?? index+2
            guard seenRowNumbers.insert(rowNumber).inserted else { throw StudyError.corrupt("重复的工作表行号。") }
            do {
                let cells = try columns(row)
                if cells.values.allSatisfy({ ($0.first("v")?.text ?? "").isEmpty && $0.all("t").allSatisfy { $0.text.isEmpty } && $0.first("f") == nil }) { continue }
                func value(_ title: String) throws -> String { guard let col = titles[title], let cell = cells[col] else { return "" }; return try cellString(cell) }
                func decimal(_ title: String) throws -> String {
                    let text = normalize(try value(title))
                    guard let col = titles[title], let c = cells[col], (c.attributes["t"] ?? "n") == "n", !text.isEmpty else { return text }
                    guard let number = Decimal(string: text,locale: Locale(identifier: "en_US_POSIX")), !number.isNaN else { throw StudyError.invalid("\(title)不是有效数值。") }
                    return NSDecimalNumber(decimal: number).stringValue
                }
                func rank(_ title: String) throws -> Int? {
                    let text = try decimal(title)
                    if text.isEmpty { return nil }
                    let d = try Score.parse(text)
                    guard d > 0, d % 100 == 0 else { throw StudyError.invalid("\(title)必须为正整数。") }; return Int(d/100)
                }
                let subject = normalize(try value("科目")); guard !subject.isEmpty else { throw StudyError.invalid("科目不能为空。") }
                let dateText = normalize(try value("时间")), date: LocalDate
                if let col = titles["时间"], let cell = cells[col], (cell.attributes["t"] ?? "n") == "n" {
                    guard let style = Int(cell.attributes["s"] ?? ""), dateStyles.contains(style), let serial = Double(dateText) else { throw StudyError.invalid("数字日期必须带日期样式。") }
                    date = try LocalDate.excel(serial: serial,system1904: system1904)
                    if serial.rounded(.down) != serial { issues.append(.init(row: rowNumber,reason: "日期含时间，确认后只保留日期。",warning: true)) }
                } else { date = try LocalDate(dateText) }
                let category = normalize(try value("分类"))
                if !category.isEmpty, ExamType.fromLabel(category) == nil { issues.append(.init(row: rowNumber,reason: "未知分类“\(category)”，确认后归类其他。",warning: true)) }
                let fullText = try decimal("满分")
                let full = fullText.isEmpty ? nil : try Score.parse(fullText)
                let score = try Score.parse(decimal("分数"))
                if let full, full <= 0 || score > full { throw StudyError.invalid("满分须大于零，且不能低于分数。") }
                let name = try value("考试名称"), reflection = try value("反思")
                guard name.count <= 100, reflection.count <= 10000 else { throw StudyError.invalid("名称或反思过长。") }
                rows.append(ExchangeRow(row: rowNumber,semester: normalize(try value("学期")),subject: subject,name: name,date: date,score: score,fullScore: full,type: ExamType.fromLabel(category) ?? .other,classRank: try rank("班排"),gradeRank: try rank("年排"),districtRank: try rank("区排"),reflection: reflection.isEmpty ? nil : reflection))
            } catch { issues.append(.init(row: rowNumber,reason: error.localizedDescription)) }
        }
        guard !rows.isEmpty || !issues.isEmpty else { throw StudyError.invalid("没有可导入的成绩。") }
        return ParsedWorkbook(rows: rows,issues: issues)
    }
}
