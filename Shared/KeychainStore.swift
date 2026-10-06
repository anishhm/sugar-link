import Foundation
import Security

/// Small Keychain wrapper. On the watch, the app and the complications share
/// an access group (Info.plist `KeychainGroup`) so complications can refresh too.
enum KeychainStore {
    // Kept from the old name "Sugar Tracker": changing it would lose the saved login.
    private static let service = "SugarTracker"

    private static var accessGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "KeychainGroup") as? String,
              !group.isEmpty, !group.hasPrefix("$(")
        else { return nil }
        return group
    }

    private static func baseQuery(_ key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    static func data(for key: String) -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func set(_ data: Data?, for key: String) {
        let query = baseQuery(key)
        SecItemDelete(query as CFDictionary)
        guard let data else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        // Background refreshes run while the watch is locked.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func value<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        data(for: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    static func setValue<T: Encodable>(_ value: T?, for key: String) {
        set(value.flatMap { try? JSONEncoder().encode($0) }, for: key)
    }
}

enum CredentialStore {
    static var credentials: LibreCredentials? {
        get { KeychainStore.value(LibreCredentials.self, for: "credentials") }
        set {
            if newValue != credentials { session = nil }
            KeychainStore.setValue(newValue, for: "credentials")
        }
    }

    static var session: LibreSession? {
        get { KeychainStore.value(LibreSession.self, for: "session") }
        set { KeychainStore.setValue(newValue, for: "session") }
    }
}
