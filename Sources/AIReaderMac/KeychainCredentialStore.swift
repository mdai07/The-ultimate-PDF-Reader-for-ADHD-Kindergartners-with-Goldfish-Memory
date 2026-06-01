import Foundation
import PaperReaderCore
import Security

struct KeychainCredentialStore {
    enum StoreError: LocalizedError {
        case unreadableStatus(OSStatus)
        case unwritableStatus(OSStatus)
        case invalidData

        var errorDescription: String? {
            switch self {
            case .unreadableStatus(let status):
                return "Keychain read failed with status \(status)."
            case .unwritableStatus(let status):
                return "Keychain write failed with status \(status)."
            case .invalidData:
                return "Keychain item could not be decoded as UTF-8."
            }
        }
    }

    func readCredential(for descriptor: ProviderCredentialDescriptor) throws -> String? {
        var query = baseQuery(for: descriptor)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw StoreError.unreadableStatus(status)
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidData
        }
        return value
    }

    func saveCredential(_ value: String, for descriptor: ProviderCredentialDescriptor) throws {
        let data = Data(value.utf8)
        let query = baseQuery(for: descriptor)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw StoreError.unwritableStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw StoreError.unwritableStatus(addStatus)
        }
    }

    func deleteCredential(for descriptor: ProviderCredentialDescriptor) throws {
        let status = SecItemDelete(baseQuery(for: descriptor) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unwritableStatus(status)
        }
    }

    private func baseQuery(for descriptor: ProviderCredentialDescriptor) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: descriptor.keychainService,
            kSecAttrAccount as String: descriptor.keychainAccount
        ]
    }
}
