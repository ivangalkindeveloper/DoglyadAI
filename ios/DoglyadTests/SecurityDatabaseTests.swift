@testable import DoglyadDatabase
import Foundation
import Security
import Testing

struct SecurityDatabaseTests {
    @Test
    func requestLimitDistinguishesMissingDataAndUpdatesExistingRecord() async throws {
        let service = "doglyad.tests.\(UUID())"
        let store = DSecurityDatabase(
            service: service,
        )
        defer { SecItemDelete(
            query(
                service: service,
            ) as CFDictionary,
        ) }
        #expect(
            try await store.fetchRequestLimit { $0 } == nil,
        )

        let date = Date()
        try await store.setRequestLimit(
            value: RequestLimitDB(
                count: 1,
                date: date,
            ),
        )
        try await store.incrementRequestCount()
        #expect(
            try await store.fetchRequestLimit { $0?.count } == 2,
        )
        let replacement = RequestLimitDB(
            count: 7,
            date: date,
        )
        try await store.setRequestLimit(
            value: replacement,
        )
        #expect(
            try await store.fetchRequestLimit { $0 } == replacement,
        )
        try await store.clearRequestLimit()
        #expect(
            try await store.fetchRequestLimit { $0 } == nil,
        )
    }

    @Test
    func corruptedLimitThrowsAndCannotBeResetByIncrement() async throws {
        let service = "doglyad.tests.\(UUID())"
        let invalidData = Data(
            "invalid JSON".utf8,
        )
        var insertion = query(
            service: service,
        )
        insertion[
            kSecValueData as String,
        ] = invalidData
        try #require(
            SecItemAdd(
                insertion as CFDictionary,
                nil,
            ) == errSecSuccess,
        )
        defer { SecItemDelete(
            query(
                service: service,
            ) as CFDictionary,
        ) }
        let store = DSecurityDatabase(
            service: service,
        )
        do {
            _ = try await store.fetchRequestLimit { $0 }
            Issue.record(
                "Corrupted data must throw instead of appearing absent",
            )
        } catch is DecodingError {} catch {
            Issue.record(
                "Unexpected read error: \(error)",
            )
        }
        do {
            try await store.incrementRequestCount()
            Issue.record(
                "A failed read must not reset the counter",
            )
        } catch is DecodingError {} catch {
            Issue.record(
                "Unexpected increment error: \(error)",
            )
        }
        var read = query(
            service: service,
        )
        read[
            kSecReturnData as String,
        ] = true
        var result: AnyObject?
        #expect(
            SecItemCopyMatching(
                read as CFDictionary,
                &result,
            ) == errSecSuccess,
        )
        #expect(
            result as? Data == invalidData,
        )
    }

    private func query(
        service: String,
    ) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: DKeychainKey.requestLimit.rawValue,
        ]
    }
}
