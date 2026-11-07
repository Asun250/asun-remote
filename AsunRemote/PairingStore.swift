import Foundation
import Security

struct PairingCredential: Codable {
    let clientKey: String
    let certificate: Data?
}

enum PairingStore {
    private static let service = "com.asunstudios.remote.pairing"

    static func load(for endpoint: TVEndpoint) throws -> PairingCredential? {
        var query = baseQuery(endpoint)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw RemoteError.message("The saved pairing could not be read from your iPhone’s Keychain (\(status)).")
        }
        return try JSONDecoder().decode(PairingCredential.self, from: data)
    }

    static func save(_ credential: PairingCredential, for endpoint: TVEndpoint) throws {
        let data = try JSONEncoder().encode(credential)
        let query = baseQuery(endpoint)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw RemoteError.message("Connected, but pairing could not be saved (\(status)). You may need to approve the TV again next time.")
        }
    }

    static func delete(for endpoint: TVEndpoint) throws {
        let status = SecItemDelete(baseQuery(endpoint) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RemoteError.message("The saved pairing could not be removed (\(status)).")
        }
    }

    private static func baseQuery(_ endpoint: TVEndpoint) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: endpoint.storageKey]
    }
}
