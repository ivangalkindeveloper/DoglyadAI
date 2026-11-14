@testable import Doglyad
import DoglyadDatabase
@testable import DoglyadNetwork
import Foundation
import Testing

struct BillingHttpInterceptorTests {
    init() {}

    @Test
    func independentInterceptorsPreserveHeadersInOrder() async throws {
        let storage = InterceptorTestSecurityDatabase()
        let adapter = DHttpInterceptorAdapter(
            interceptors: [
                DLocaleInterceptor(
                    preferredLanguageIdentifiers: ["ru-RU", "en-US"],
                ),
                InterceptorTestAppCheck(),
                BillingHttpInterceptor(
                    baseUrl: URL(
                        string: "https://api.example",
                    )!,
                    baseVersionPrefix: "/v1",
                    securityDatabase: storage,
                ),
            ],
        )
        let result: URLRequest = try await withCheckedThrowingContinuation { continuation in
            adapter.adapt(
                URLRequest(
                    url: URL(
                        string: "https://api.example/v1/subscriptions/status",
                    )!,
                ),
                for: .default,
                completion: {
                    continuation.resume(
                        with: $0,
                    )
                },
            )
        }
        #expect(
            result.value(
                forHTTPHeaderField: DHttpHeader.acceptLanguage,
            ) == "ru-RU, en-US",
        )
        #expect(
            result.value(
                forHTTPHeaderField: "X-Firebase-AppCheck",
            ) == "test-attestation",
        )
        #expect(
            result.value(
                forHTTPHeaderField: "Authorization",
            ) == "Bearer test-secret",
        )
    }

    @Test
    func failedAttestationStopsBeforeReadingOwnerSecret() async {
        let storage = InterceptorTestSecurityDatabase()
        let adapter = DHttpInterceptorAdapter(
            interceptors: [
                InterceptorTestAppCheck(
                    isFailure: true,
                ),
                BillingHttpInterceptor(
                    baseUrl: URL(
                        string: "https://api.example",
                    )!,
                    baseVersionPrefix: "/v1",
                    securityDatabase: storage,
                ),
            ],
        )
        await #expect(
            throws: URLError.self,
        ) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URLRequest, Error>) in
                adapter.adapt(
                    URLRequest(
                        url: URL(
                            string: "https://api.example/v1/subscriptions/status",
                        )!,
                    ),
                    for: .default,
                    completion: {
                        continuation.resume(
                            with: $0,
                        )
                    },
                )
            }
        }
        #expect(
            await storage.readCount == 0,
        )
    }

    @Test(
        arguments: [
            "https://other.example/v1/subscriptions/status",
            "http://api.example/v1/subscriptions/status",
            "https://api.example:8443/v1/subscriptions/status",
            "https://api.example/pay",
            "https://api.example/v10/status",
        ],
    )
    func ownerSecretIsNotSentOutsideApplicationAPI(
        url: String,
    ) async throws {
        let storage = InterceptorTestSecurityDatabase()
        let interceptor = BillingHttpInterceptor(
            baseUrl: URL(
                string: "https://api.example",
            )!,
            baseVersionPrefix: "/v1",
            securityDatabase: storage,
        )
        let result = try await interceptor.adapt(
            URLRequest(
                url: URL(
                    string: url,
                )!,
            ),
        )
        #expect(
            result.value(
                forHTTPHeaderField: "Authorization",
            ) == nil,
        )
        #expect(
            await storage.readCount == 0,
        )
    }

    @Test(
        arguments: [
            "https://api.example/gateway/v2/subscriptions/status",
            "https://api.example/gateway/v20/subscriptions/status",
            "https://api.example/gateway/v1/subscriptions/status",
            "https://api.example/v2/subscriptions/status",
            "https://api.example/gateway/pay",
        ],
    )
    func ownerSecretUsesTheConfiguredAPIPath(
        url: String,
    ) async throws {
        let storage = InterceptorTestSecurityDatabase()
        let interceptor = BillingHttpInterceptor(
            baseUrl: URL(
                string: "https://api.example/gateway",
            )!,
            baseVersionPrefix: "/v2",
            securityDatabase: storage,
        )
        let result = try await interceptor.adapt(
            URLRequest(
                url: URL(
                    string: url,
                )!,
            ),
        )
        let isApplicationAPI = url == "https://api.example/gateway/v2/subscriptions/status"
        #expect(
            result.value(
                forHTTPHeaderField: "Authorization",
            ) == (isApplicationAPI ? "Bearer test-secret" : nil),
        )
        #expect(
            await storage.readCount == (isApplicationAPI ? 1 : 0),
        )
    }
}

private struct InterceptorTestAppCheck: DHttpInterceptorProtocol {
    var isFailure = false

    init(
        isFailure: Bool = false,
    ) {
        self.isFailure = isFailure
    }

    func adapt(
        _ urlRequest: URLRequest,
    ) async throws -> URLRequest {
        if isFailure {
            throw URLError(
                .userAuthenticationRequired,
            )
        }
        var request = urlRequest
        request.setValue(
            "test-attestation",
            forHTTPHeaderField: "X-Firebase-AppCheck",
        )
        return request
    }
}

private actor InterceptorTestSecurityDatabase: DSecurityDatabaseProtocol {
    private(set) var readCount = 0

    func fetchBillingIdentity() async throws -> BillingIdentityDB? {
        readCount += 1
        return BillingIdentityDB(
            ownerId: UUID(),
            accessToken: "test-secret",
        )
    }

    func setBillingIdentity(
        value _: BillingIdentityDB,
    ) async throws {}

    func removeBillingIdentity() async throws {}

    func setBillingRecoveryKey(
        ownerId: UUID,
        value: String,
    ) async throws {
        guard let current = try await fetchBillingIdentity(), current.ownerId == ownerId else {
            throw CancellationError()
        }
        try await setBillingIdentity(
            value: BillingIdentityDB(
                ownerId: ownerId,
                accessToken: current.accessToken,
                recoveryKey: value,
            ),
        )
    }
}
