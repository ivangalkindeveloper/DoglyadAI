@testable import DoglyadDatabase
import Foundation
import Security
import Testing

struct SecurityDatabaseTests {
    @Test
    func billingIdentityDistinguishesMissingDataAndUpdatesExistingRecord() async throws {
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
            try await store.fetchBillingIdentity() == nil,
        )
        let ownerId = UUID()
        try await store.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: ownerId,
                accessToken: "first-secret",
            ),
        )
        let initial = try #require(
            await store.fetchBillingIdentity(),
        )
        #expect(
            initial.ownerId == ownerId,
        )
        #expect(
            initial.accessToken == "first-secret",
        )
        let restoredOwnerId = UUID()
        try await store.setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: restoredOwnerId,
                accessToken: "restored-secret",
            ),
        )
        let restored = try #require(
            await store.fetchBillingIdentity(),
        )
        #expect(
            restored.ownerId == restoredOwnerId,
        )
        #expect(
            restored.accessToken == "restored-secret",
        )
    }

    @Test
    func corruptedBillingIdentityThrowsAndIsNotSilentlyReplaced() async throws {
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
            _ = try await store.fetchBillingIdentity()
            Issue.record(
                "Corrupted identity must throw instead of registering a new billing owner",
            )
        } catch is DecodingError {} catch {
            Issue.record(
                "Unexpected read error: \(error)",
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
            kSecAttrAccount as String: DKeychainKey.billingIdentity.rawValue,
        ]
    }
}
