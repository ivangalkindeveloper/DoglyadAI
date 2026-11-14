@testable import Doglyad

@MainActor
func makeStateTestContainer(
    reportRepository: UltrasoundReportRepositoryProtocol,
    draftRepository: UltrasoundDraftRepositoryProtocol,
    templateRepository: (any TemplateRepositoryProtocol)? = nil,
    settingsAIRepository: (any SettingsAIRepositoryProtocol)? = nil,
    userSettingsRepository: (any UserSettingsRepositoryProtocol)? = nil,
    subscriptionBackendRepository: (any SubscriptionBackendRepositoryProtocol)? = nil,
    applicationConfig: ApplicationConfig? = nil,
    usExaminationTypesById: [String: USExaminationType]? = nil,
) -> DependencyContainer {
    let base = DependencyContainer.previewable
    return DependencyContainer(
        analytics: base.analytics,
        environment: base.environment,
        connectionManager: base.connectionManager,
        permissionManager: base.permissionManager,
        mockFactory: base.mockFactory,
        sharedRepository: base.sharedRepository,
        userSettingsRepository: userSettingsRepository ?? base.userSettingsRepository,
        settingsAIRepository: settingsAIRepository ?? base.settingsAIRepository,
        ultrasoundReportRepository: reportRepository,
        ultrasoundDraftRepository: draftRepository,
        templateRepository: templateRepository ?? base.templateRepository,
        subscriptionBackendRepository: subscriptionBackendRepository ?? base.subscriptionBackendRepository,
        subscriptionStoreKitRepository: base.subscriptionStoreKitRepository,
        subscriptionRepositoryFactory: base.subscriptionRepositoryFactory,
        applicationConfig: applicationConfig ?? base.applicationConfig,
        language: base.language,
        l10n: base.l10n,
        examinationNeuralModelFactory: base.examinationNeuralModelFactory,
        usExaminationTypeGroups: base.usExaminationTypeGroups,
        usExaminationTypesById: usExaminationTypesById ?? base.usExaminationTypesById,
        usExaminationTypeDefault: base.usExaminationTypeDefault,
        usExaminationNeuralModels: base.usExaminationNeuralModels,
        usExaminationNeuralModelsById: base.usExaminationNeuralModelsById,
        usExaminationNeuralModelDefault: base.usExaminationNeuralModelDefault,
        initialUserSettings: base.initialUserSettings,
        initialSettingsAI: base.initialSettingsAI,
        initialSubscriptionStatus: nil,
        initialRoute: base.initialRoute,
        version: base.version,
    )
}
