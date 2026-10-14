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

    // MARK: - Request limit CRUD

    public func fetchRequestLimit<T: Sendable>(
        _ transform: @Sendable (RequestLimitDB?) -> T,
    ) throws -> T {
        try transform(
            readRequestLimit(),
        )
    }

    public func setRequestLimit(
        value: RequestLimitDB,
    ) throws {
        let data = try encoder.encode(
            value,
        )
        try write(
            data: data,
            key: .requestLimit,
        )
    }

    public func clearRequestLimit() throws {
        try delete(
            key: .requestLimit,
        )
    }

    public func incrementRequestCount() throws {
        let current = try readRequestLimit()
        let updated = if let current,
                         Calendar.current.isDateInToday(
                             current.date,
                         )
        {
            RequestLimitDB(
                count: current.count + 1,
                date: current.date,
            )
        } else {
            RequestLimitDB(
                count: 1,
                date: Date(),
            )
        }
        try setRequestLimit(
            value: updated,
        )
    }

    private func readRequestLimit() throws -> RequestLimitDB? {
        guard let data = try read(
            key: .requestLimit,
        ) else { return nil }
        return try decoder.decode(
            RequestLimitDB.self,
            from: data,
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
        if status == errSecSuccess { return }
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

    private func delete(
        key: DKeychainKey,
    ) throws {
        let status = SecItemDelete(
            baseQuery(
                key: key,
            ) as CFDictionary,
        )
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DSecurityDatabaseError.unhandled(
                status: status,
            )
        }
    }
}
