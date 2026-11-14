@testable import DependencyInitializer
@testable import Doglyad
import DoglyadDatabase
import Foundation
import Testing

@MainActor
struct LocalBillingResetInitializationTests {
    init() {}

    @Test(
        arguments: ["com.medical.doglyad.local", "com.medical.doglyad.development", "com.medical.doglyad"],
    )
    func cleanArgumentAppliesOnlyToLocalBundle(
        bundleIdentifier: String,
    ) async {
        let store = LocalResetTestSecurityDatabase()
        let process = InitializationProcess()
        process.securityDatabase = store
        process.environment = EnvironmentBase(
            type: .development,
            baseUrl: URL(
                string: "http://127.0.0.1:8000",
            )!,
        )
        var failed = false
        await DependencyInitializer<InitializationProcess, DependencyContainer>(
            createProcess: {
                process
            },
            stepSets: [InitializationProcess.stepsLocalBillingReset(
                arguments: ["--reset-local-billing-identity"],
                bundleIdentifier: bundleIdentifier,
            )],
            onError: { _, _, _, _ in
                failed = true
            },
        ).run()
        #expect(
            !failed,
        )
        #expect(
            await store.removalCount == (bundleIdentifier == "com.medical.doglyad.local" ? 1 : 0),
        )
    }

    @Test(
        arguments: [EnvironmentType.development, .production],
    )
    func ordinaryLaunchDoesNotRemoveBillingIdentity(
        environment: EnvironmentType,
    ) async {
        let store = LocalResetTestSecurityDatabase()
        let process = InitializationProcess()
        process.securityDatabase = store
        process.environment = EnvironmentBase(
            type: environment,
            baseUrl: URL(
                string: "http://127.0.0.1:8000",
            )!,
        )
        await DependencyInitializer<InitializationProcess, DependencyContainer>(
            createProcess: {
                process
            },
            stepSets: [InitializationProcess.stepsLocalBillingReset(
                arguments: [],
                bundleIdentifier: "com.medical.doglyad.local",
            )],
        ).run()
        #expect(
            await store.removalCount == 0,
        )
    }

    @Test
    func productionConfigurationIgnoresCleanArgument() async {
        let store = LocalResetTestSecurityDatabase()
        let process = InitializationProcess()
        process.securityDatabase = store
        process.environment = EnvironmentBase(
            type: .production,
            baseUrl: URL(
                string: "https://api.doglyad.ru",
            )!,
        )
        await DependencyInitializer<InitializationProcess, DependencyContainer>(
            createProcess: {
                process
            },
            stepSets: [InitializationProcess.stepsLocalBillingReset(
                arguments: ["--reset-local-billing-identity"],
                bundleIdentifier: "com.medical.doglyad.local",
            )],
        ).run()
        #expect(
            await store.removalCount == 0,
        )
    }
}

private actor LocalResetTestSecurityDatabase: DSecurityDatabaseProtocol {
    private(set) var removalCount = 0

    func fetchBillingIdentity() async throws -> BillingIdentityDB? {
        nil
    }

    func setBillingIdentity(
        value _: BillingIdentityDB,
    ) async throws {}

    func removeBillingIdentity() async throws {
        removalCount += 1
    }

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
