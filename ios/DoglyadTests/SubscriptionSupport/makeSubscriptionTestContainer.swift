@testable import Doglyad

@MainActor
func makeSubscriptionTestContainer(
    backend: SubscriptionBackendRepositoryProtocol,
    storeKit: SubscriptionRepositoryProtocol,
    robokassa: SubscriptionRepositoryProtocol,
    getStorefrontCountryCode: @escaping () async -> String? = {
        nil
    },
    l10n: L10N? = nil,
) -> DependencyContainer {
    let base = DependencyContainer.makePreviewable(
        l10n: l10n,
    )
    let factory = SubscriptionTestRepositoryFactory {
        await getStorefrontCountryCode() == "RUS" ? robokassa : storeKit
    }
    return DependencyContainer(
        analytics: base.analytics,
        environment: base.environment,
        connectionManager: base.connectionManager,
        permissionManager: base.permissionManager,
        mockFactory: base.mockFactory,
        sharedRepository: base.sharedRepository,
        userSettingsRepository: base.userSettingsRepository,
        settingsAIRepository: base.settingsAIRepository,
        ultrasoundReportRepository: base.ultrasoundReportRepository,
        ultrasoundDraftRepository: base.ultrasoundDraftRepository,
        templateRepository: base.templateRepository,
        subscriptionBackendRepository: backend,
        subscriptionStoreKitRepository: storeKit,
        subscriptionRepositoryFactory: factory,
        applicationConfig: base.applicationConfig,
        language: base.language,
        l10n: base.l10n,
        examinationNeuralModelFactory: base.examinationNeuralModelFactory,
        usExaminationTypeGroups: base.usExaminationTypeGroups,
        usExaminationTypesById: base.usExaminationTypesById,
        usExaminationTypeDefault: base.usExaminationTypeDefault,
        usExaminationNeuralModels: base.usExaminationNeuralModels,
        usExaminationNeuralModelsById: base.usExaminationNeuralModelsById,
        usExaminationNeuralModelDefault: base.usExaminationNeuralModelDefault,
        initialSubscriptionStatus: nil,
        initialRoute: base.initialRoute,
        version: base.version,
    )
}
