import Foundation

extension Preferences {
    public var profileAvatars: [String: String] {
        guard case .object(let ios) = platformExtensions["ios"], case .object(let avatars) = ios["profileAvatars"] else { return [:] }
        return avatars.compactMapValues { if case .string(let id) = $0 { return id }; return nil }
    }
    public func avatarAssetID(for userID: String) -> String? { profileAvatars[userID] }
    public mutating func setAvatarAssetID(_ id: String?, for userID: String) {
        var ios: [String: JSONValue] = [:]
        if case .object(let existing) = platformExtensions["ios"] { ios = existing }
        var avatars = profileAvatars
        avatars[userID] = id
        ios["profileAvatars"] = .object(avatars.mapValues { .string($0) })
        platformExtensions["ios"] = .object(ios)
    }
}
