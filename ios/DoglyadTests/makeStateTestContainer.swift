@testable import Doglyad

@MainActor
func makeStateTestContainer(
    reportRepository: UltrasoundReportRepositoryProtocol,
    draftRepository: UltrasoundDraftRepositoryProtocol,
    settingsAIRepository: (any SettingsAIRepositoryProtocol)? = nil,
) -> DependencyContainer {
    let base = DependencyContainer.previewable
    return DependencyContainer(
        analytics: base.analytics,
        environment: base.environment,
        connectionManager: base.connectionManager,
        permissionManager: base.permissionManager,
        mockFactory: base.mockFactory,
        sharedRepository: base.sharedRepository,
        userSettingsRepository: base.userSettingsRepository,
        settingsAIRepository: settingsAIRepository ?? base.settingsAIRepository,
        ultrasoundReportRepository: reportRepository,
        ultrasoundDraftRepository: draftRepository,
        templateRepository: base.templateRepository,
        subscriptionRepository: base.subscriptionRepository,
        applicationConfig: base.applicationConfig,
        language: base.language,
        l10n: base.l10n,
        usExaminationTypeGroups: base.usExaminationTypeGroups,
        usExaminationTypesById: base.usExaminationTypesById,
        usExaminationTypeDefault: base.usExaminationTypeDefault,
        usExaminationNeuralModels: base.usExaminationNeuralModels,
        usExaminationNeuralModelsById: base.usExaminationNeuralModelsById,
        usExaminationNeuralModelDefault: base.usExaminationNeuralModelDefault,
        examinationNeuralModelFactory: base.examinationNeuralModelFactory,
        initialSubscriptionStatus: nil,
        initialUserSettings: base.initialUserSettings,
        initialSettingsAI: base.initialSettingsAI,
        initialRoute: base.initialRoute,
        version: base.version,
    )
}
