import Foundation

public struct RGBColor: Equatable, Sendable {
    public var red: Int; public var green: Int; public var blue: Int
    public init(red: Int, green: Int, blue: Int) { self.red = min(255,max(0,red)); self.green = min(255,max(0,green)); self.blue = min(255,max(0,blue)) }
    public var hex: String { String(format: "#%02X%02X%02X",red,green,blue) }
    public static func parse(_ text: String) -> Self? {
        let value = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard value.count == 6, value.allSatisfy({ $0.isHexDigit }), let n = UInt32(value,radix: 16) else { return nil }
        return Self(red: Int(n >> 16),green: Int((n >> 8) & 255),blue: Int(n & 255))
    }
    public var luminance: Double {
        func channel(_ value: Int) -> Double { let c = Double(value)/255; return c <= 0.04045 ? c/12.92 : pow((c+0.055)/1.055,2.4) }
        return 0.2126*channel(red)+0.7152*channel(green)+0.0722*channel(blue)
    }
    public var usesDarkText: Bool { luminance > 0.179 }
}
extension Preferences {
    public func appearanceValue(_ key: String) -> String? {
        guard case .object(let ios) = platformExtensions["ios"], case .string(let value) = ios[key] else { return nil }; return value
    }
    public mutating func setAppearanceValue(_ value: String, for key: String) {
        var ios: [String: JSONValue] = [:]
        if case .object(let existing) = platformExtensions["ios"] { ios = existing }
        ios[key] = .string(value); platformExtensions["ios"] = .object(ios)
    }
    public var displayMode: String { get { appearanceValue("displayMode") ?? "system" } set { setAppearanceValue(newValue,for: "displayMode") } }
    public var glassVariant: String { get { appearanceValue("glassVariant") ?? "regular" } set { setAppearanceValue(newValue,for: "glassVariant") } }
    public var glassTint: Double { get { min(0.5,max(0,Double(appearanceValue("glassTint") ?? "0.08") ?? 0.08)) } set { setAppearanceValue(String(min(0.5,max(0,newValue))),for: "glassTint") } }
    public var glassBacking: Double { get { min(0.8,max(0,Double(appearanceValue("glassBacking") ?? "0.15") ?? 0.15)) } set { setAppearanceValue(String(min(0.8,max(0,newValue))),for: "glassBacking") } }
}
