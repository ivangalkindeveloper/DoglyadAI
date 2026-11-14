import Foundation
import Security

public enum DSecurityDatabaseError: Error {
    case unhandled(status: OSStatus)
}

public actor DSecurityDatabase: DSecurityDatabaseProtocol {
    private let service: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.doglyad.app",
    ) {
        self.service = service
    }

    public func fetchBillingIdentity() throws -> BillingIdentityDB? {
        guard let data = try read(
            key: .billingIdentity,
        ) else {
            return nil
        }
        return try decoder.decode(
            BillingIdentityDB.self,
            from: data,
        )
    }

    public func setBillingIdentity(
        value: BillingIdentityDB,
    ) throws {
        try write(
            data: encoder.encode(
                value,
            ),
            key: .billingIdentity,
        )
    }

    public func removeBillingIdentity() throws {
        let status = SecItemDelete(
            baseQuery(
                key: .billingIdentity,
            ) as CFDictionary,
        )
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw DSecurityDatabaseError.unhandled(
                status: status,
            )
        }
    }

    public func setBillingRecoveryKey(
        ownerId: UUID,
        value: String,
    ) throws {
        guard let identity = try fetchBillingIdentity(), identity.ownerId == ownerId else {
            throw CancellationError()
        }
        try setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: identity.ownerId,
                accessToken: identity.accessToken,
                recoveryKey: value,
            ),
        )
    }

    // MARK: - Keychain

    private func baseQuery(
        key: DKeychainKey,
    ) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }

    private func read(
        key: DKeychainKey,
    ) throws -> Data? {
        var query = baseQuery(
            key: key,
        )
        query[
            kSecReturnData as String,
        ] = true
        query[
            kSecMatchLimit as String,
        ] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result,
        )
        switch status {
        case errSecItemNotFound:
            return nil
        case errSecSuccess:
            guard let data = result as? Data else {
                throw DSecurityDatabaseError.unhandled(
                    status: errSecDecode,
                )
            }
            return data
        default:
            throw DSecurityDatabaseError.unhandled(
                status: status,
            )
        }
    }

    private func write(
        data: Data,
        key: DKeychainKey,
    ) throws {
        let status = SecItemUpdate(
            baseQuery(
                key: key,
            ) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary,
        )
        if status == errSecSuccess {
            return
        }
        guard status == errSecItemNotFound else {
            throw DSecurityDatabaseError.unhandled(
                status: status,
            )
        }
        var query = baseQuery(
            key: key,
        )
        query[
            kSecValueData as String,
        ] = data
        query[
            kSecAttrAccessible as String,
        ] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let insertionStatus = SecItemAdd(
            query as CFDictionary,
            nil,
        )
        guard insertionStatus == errSecSuccess else {
            throw DSecurityDatabaseError.unhandled(
                status: insertionStatus,
            )
        }
    }
}
