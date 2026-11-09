import Combine
@testable import Doglyad
import DoglyadDatabase
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct PatientConsentTests {
    @Test
    func preferenceDefaultsToTrueAndSurvivesRepositoryReload() async throws {
        let suite = "PatientConsentTests.\(UUID())"
        let defaults = try #require(
            UserDefaults(
                suiteName: suite,
            ),
        )
        defer {
            defaults.removePersistentDomain(
                forName: suite,
            )
        }
        let database = try DDatabase(
            defaults: defaults,
        )
        let base = try #require(
            DependencyContainer.previewable.userSettingsRepository as? UserSettingsRepository,
        )
        let repository = UserSettingsRepository(
            database: database,
            httpClient: base.httpClient,
        )
        #expect(
            try await repository.getIsNeedPatientConsent(),
        )
        try await repository.setIsNeedPatientConsent(
            false,
        )
        let reloaded = try UserSettingsRepository(
            database: DDatabase(
                defaults: defaults,
            ),
            httpClient: base.httpClient,
        )
        #expect(
            try await !reloaded.getIsNeedPatientConsent(),
        )
        try await reloaded.setIsNeedPatientConsent(
            true,
        )
        #expect(
            try await repository.getIsNeedPatientConsent(),
        )
        defaults.set(
            "invalid",
            forKey: "isNeedPatientConsent",
        )
        #expect(
            try await repository.getIsNeedPatientConsent(),
        )
    }

    @Test(
        arguments: [false, true],
    )
    func confirmationPersistsChoiceBeforeDismissalAndCallsBackOnce(
        isDoNotAskAgain: Bool,
    ) async {
        let container = DependencyContainer.previewable
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        var resume: CheckedContinuation<Void, Never>?
        var writes: [Bool] = []
        var confirmations = 0
        let arguments = PatientConsentArguments(
            onConfirm: {
                confirmations += 1
            },
        )
        router.push(
            route: RouteSheet(
                type: .patientConsent,
                arguments: arguments,
            ),
        )
        let model = makeModel(
            container: container,
            router: router,
            arguments: arguments,
            onSaved: {
                writes.append(
                    $0,
                )
                await withCheckedContinuation {
                    resume = $0
                }
            },
        )
        model.onDoNotAskAgainChanged(
            isDoNotAskAgain,
        )
        let state = model.state
        model.onTapConfirm()
        let task = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        model.onTapConfirm()
        #expect(
            model.state === state && router.sheet?.type == .patientConsent && confirmations == 0,
        )
        #expect(
            writes == [!isDoNotAskAgain],
        )
        resume?.resume()
        await task?.value
        model.onTapConfirm()
        #expect(
            router.sheet == nil && confirmations == 1 && writes == [!isDoNotAskAgain],
        )
    }

    @Test
    func failedPreferenceSaveRetainsChoiceAndAllowsRetry() async {
        let container = DependencyContainer.previewable
        let repository = PatientConsentRepository(
            wrapped: container.userSettingsRepository,
        )
        repository.onWrite = { _ in
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        let messager = DMessager()
        var errors = 0
        let observation = messager.$message.dropFirst().sink { _ in
            errors += 1
        }
        defer {
            observation.cancel()
        }
        var confirmations = 0
        let arguments = PatientConsentArguments(
            onConfirm: {
                confirmations += 1
            },
        )
        router.push(
            route: RouteSheet(
                type: .patientConsent,
                arguments: arguments,
            ),
        )
        let model = makeModel(
            container: container,
            router: router,
            messager: messager,
            arguments: arguments,
            onSaved: repository.setIsNeedPatientConsent,
        )
        model.onDoNotAskAgainChanged(
            true,
        )
        model.onTapConfirm()
        await model.lastTask?.value
        #expect(
            repository.isNeedPatientConsent && model.state.isDoNotAskAgain && errors == 1,
        )
        #expect(
            router.sheet != nil && confirmations == 0,
        )
        repository.onWrite = nil
        model.onTapConfirm()
        await model.lastTask?.value
        #expect(
            !repository.isNeedPatientConsent && router.sheet == nil && confirmations == 1,
        )
    }

    @Test
    func dismissalRejectsLateConfirmation() async {
        let container = DependencyContainer.previewable
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        var resume: CheckedContinuation<Void, Never>?
        var confirmations = 0
        let model = makeModel(
            container: container,
            router: router,
            arguments: PatientConsentArguments(
                onConfirm: {
                    confirmations += 1
                },
            ),
            onSaved: { _ in
                await withCheckedContinuation {
                    resume = $0
                }
            },
        )
        model.onTapConfirm()
        let task = model.lastTask
        while resume == nil {
            await Task.yield()
        }
        model.onDisappear()
        resume?.resume()
        await task?.value
        model.onTapConfirm()
        #expect(
            confirmations == 0 && model.operationTask == nil,
        )
    }

    @Test
    func sharedPreferenceUpdatesOnlyAfterSuccessfulPersistence() async throws {
        let repository = PatientConsentRepository(
            wrapped: DependencyContainer.previewable.userSettingsRepository,
        )
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            userSettingsRepository: repository,
        )
        let root = UltrasoundRootViewModel(
            container: container,
        )
        var observed: [Bool] = []
        let observation = root.observeChanges {
            observed.append(
                root.isNeedPatientConsent,
            )
        }
        defer {
            observation.cancel()
        }
        repository.onWrite = { _ in
            throw CocoaError(
                .fileWriteUnknown,
            )
        }
        do {
            try await root.saveIsNeedPatientConsent(
                false,
            )
            Issue.record(
                "A failed write must propagate",
            )
        } catch {}
        #expect(
            root.isNeedPatientConsent && observed.isEmpty,
        )
        repository.onWrite = nil
        try await root.saveIsNeedPatientConsent(
            false,
        )
        #expect(
            !root.isNeedPatientConsent && observed == [false],
        )
        try await root.saveIsNeedPatientConsent(
            true,
        )
        #expect(
            root.isNeedPatientConsent && observed == [false, true],
        )
    }

    @Test
    func settingsCanDisableAndReenableThePersistedPrompt() async throws {
        let suite = "PatientConsentSettingsTests.\(UUID())"
        let defaults = try #require(
            UserDefaults(
                suiteName: suite,
            ),
        )
        defer {
            defaults.removePersistentDomain(
                forName: suite,
            )
        }
        let base = try #require(
            DependencyContainer.previewable.userSettingsRepository as? UserSettingsRepository,
        )
        let repository = try PatientConsentRepository(
            wrapped: UserSettingsRepository(
                database: DDatabase(
                    defaults: defaults,
                ),
                httpClient: base.httpClient,
            ),
        )
        let container = makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            userSettingsRepository: repository,
        )
        let root = UltrasoundRootViewModel(
            container: container,
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        for isExpected in [false, true] {
            router.push(
                route: RouteScreen(
                    type: .workSettings,
                ),
            )
            let model = WorkSettingsViewModel(
                container: container,
                messager: DMessager(),
                router: router,
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                getInitialEmail: {
                    root.userEmail
                },
                getInitialIsNeedPatientConsent: {
                    root.isNeedPatientConsent
                },
                getInitialIsRecommendationsIncluded: {
                    root.isRecommendationsIncluded
                },
                getInitialIsPhotoRemarks: {
                    root.isPhotoRemarks
                },
                getInitialIsDescriptionRemarks: {
                    root.isDescriptionRemarks
                },
                onSaved: { email, consent, recommendations, photo, description in
                    try await root.saveUserSettings(
                        userEmail: email,
                        isNeedPatientConsent: consent,
                        isRecommendationsIncluded: recommendations,
                        isPhotoRemarks: photo,
                        isDescriptionRemarks: description,
                    )
                },
            )
            #expect(
                model.isNeedPatientConsent != isExpected,
            )
            model.togglePatientConsent()
            model.onTapSave()
            await model.lastTask?.value
            #expect(
                router.path.isEmpty && model.isNeedPatientConsent == isExpected,
            )
            #expect(
                try await repository.getIsNeedPatientConsent() == isExpected,
            )
            #expect(
                root.isNeedPatientConsent == isExpected,
            )
            model.onDisappear()
        }
    }

    private func makeModel(
        container: DependencyContainer,
        router: DRouter,
        messager: DMessager = DMessager(),
        arguments: PatientConsentArguments,
        onSaved: @escaping (Bool) async throws -> Void,
    ) -> PatientConsentViewModel {
        PatientConsentViewModel(
            messager: messager,
            container: container,
            router: router,
            arguments: arguments,
            onSaved: onSaved,
            getSubscriptionStatus: {
                nil
            },
            observeSubscriptionStatus: { _ in
                AnyCancellable {}
            },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: {
                container.initialSettingsAI
            },
            onRefreshSubscriptionStatus: {},
        )
    }
}
