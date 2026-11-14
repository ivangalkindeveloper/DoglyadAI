@testable import DependencyInitializer
@testable import Doglyad
import DoglyadNetwork
import Foundation
import Testing

@MainActor
struct L10NInitializationTests {
    init() {}

    @Test
    func failedLocalizationDoesNotPublishCatalogOrStartNextTier() async {
        let client = FailingLocalizationHttpClient()
        let process = InitializationProcess()
        process.httpClient = client
        let l10nSteps: StepSet<InitializationProcess>
        switch InitializationProcess.stepsTier4.kind {
        case let .async(
            steps,
        ):
            l10nSteps = StepSet(
                async: Array(
                    steps.prefix(
                        1,
                    ),
                ),
            )
        case .sync:
            Issue.record(
                "Tier 4 must contain asynchronous steps",
            )
            return
        }
        var failed = false
        var succeeded = false
        var nextTierStarted = false
        await DependencyInitializer<InitializationProcess, DependencyContainer>(
            createProcess: {
                process
            },
            stepSets: [
                l10nSteps,
                StepSet(
                    sync: [
                        SyncInitializationStep<InitializationProcess>(
                            title: "Next tier",
                            run: { _ in
                                nextTierStarted = true
                            },
                        ),
                    ],
                ),
            ],
            onSuccess: { _, _ in
                succeeded = true
            },
            onError: { _, _, step, _ in
                failed = true
                #expect(
                    step.title == "L10N",
                )
            },
        ).run()
        #expect(
            failed,
        )
        #expect(
            !succeeded,
        )
        #expect(
            !nextTierStarted,
        )
        #expect(
            client.requestedPaths == ["/l10n"],
        )
        #expect(
            process.l10n == nil,
        )
    }
}

private final class FailingLocalizationHttpClient: DHttpClientProtocol, @unchecked Sendable {
    let baseUrl = "http://test"
    let baseVersionPrefix = "/v1"
    private let lock = NSLock()
    private var paths: [String] = []

    init() {}

    var requestedPaths: [String] {
        lock.withLock {
            paths
        }
    }

    func updateConfiguration(
        timeoutIntervalForRequest _: TimeInterval,
        timeoutIntervalForResource _: TimeInterval,
    ) {}

    func get<Response: Decodable>(
        url _: URL,
    ) async throws -> Response {
        throw URLError(
            .notConnectedToInternet,
        )
    }

    func get<Response: Decodable>(
        endPoint: String,
        headers _: [String: String]?,
    ) async throws -> Response {
        lock.withLock {
            paths.append(
                endPoint,
            )
        }
        throw URLError(
            .notConnectedToInternet,
        )
    }

    func get<Response: Decodable>(
        endPoint _: String,
        body _: (some Encodable & Sendable)?,
        headers _: [String: String]?,
    ) async throws -> Response {
        throw URLError(
            .notConnectedToInternet,
        )
    }

    func post<Response: Decodable>(
        endPoint _: String,
        body _: (some Encodable & Sendable)?,
        headers _: [String: String]?,
        encoderUserInfo _: [CodingUserInfoKey: Any]?,
    ) async throws -> Response {
        throw URLError(
            .notConnectedToInternet,
        )
    }

    func post(
        endPoint _: String,
        body _: (some Encodable & Sendable)?,
        headers _: [String: String]?,
        encoderUserInfo _: [CodingUserInfoKey: Any]?,
    ) async throws {
        throw URLError(
            .notConnectedToInternet,
        )
    }

    func post<Response: Decodable>(
        endPoint _: String,
        data _: Data?,
        headers _: [String: String]?,
    ) async throws -> Response {
        throw URLError(
            .unsupportedURL,
        )
    }

    func serverEvents(
        endPoint _: String,
        headers _: [String: String]?,
    ) async throws -> AsyncThrowingStream<DServerEvent, Error> {
        throw URLError(
            .unsupportedURL,
        )
    }
}
