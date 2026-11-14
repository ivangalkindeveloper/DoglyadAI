import DependencyInitializer
import DoglyadDatabase
import DoglyadNetwork
import DoglyadNeuralModel
import Foundation
import Router

@MainActor
final class InitializationProcess: DependencyInitializationProcess {
    var analytics: AnalyticsManager?
    var environment: EnvironmentProtocol?
    var connectionManager: ConnectionManagerProtocol?
    var permissionManager: PermissionManagerProtocol?
    var mockFactory: MockFactoryProtocol?
    var database: DDatabase?
    var securityDatabase: DSecurityDatabaseProtocol?
    var httpClient: DHttpClientProtocol?
    var sharedRepository: SharedRepositoryProtocol?
    var userSettingsRepository: UserSettingsRepositoryProtocol?
    var settingsAIRepository: SettingsAIRepositoryProtocol?
    var ultrasoundReportRepository: UltrasoundReportRepositoryProtocol?
    var ultrasoundDraftRepository: UltrasoundDraftRepositoryProtocol?
    var templateRepository: TemplateRepositoryProtocol?
    var subscriptionBackendRepository: SubscriptionBackendRepositoryProtocol?
    var subscriptionStoreKitRepository: SubscriptionRepositoryProtocol?
    var subscriptionRepositoryFactory: SubscriptionRepositoryFactoryProtocol?
    var applicationConfig: ApplicationConfig?
    var language: Language?
    var l10n: L10N?
    var usExaminationTypeGroups: [USExaminationTypeGroup]?
    var usExaminationTypesById: [String: USExaminationType]?
    var usExaminationTypeDefault: USExaminationType?
    var usExaminationNeuralModels: [USExaminationNeuralModel]?
    var usExaminationNeuralModelsById: [String: USExaminationNeuralModel]?
    var usExaminationNeuralModelDefault: USExaminationNeuralModel?
    var examinationNeuralModelFactory: DNeuralUltrasoundModelFactory?
    var initialUltrasoundReportsCount: Int?
    var initialUserSettings: UserSettings?
    var initialSettingsAI: SettingsAI?
    var initialSubscriptionStatus: SubscriptionStatus?
    var initialRoute: RouteScreen<ScreenType>?
    var version: String?

    init() {}

    var toContainer: DependencyContainer {
        #if DEBUG && DOGLYAD_REGRESSION
            RegressionRepositoryAdapters.install(
                on: self,
            )
        #endif
        return DependencyContainer(
            analytics: analytics!,
            environment: environment!,
            connectionManager: connectionManager!,
            permissionManager: permissionManager!,
            mockFactory: mockFactory!,
            sharedRepository: sharedRepository!,
            userSettingsRepository: userSettingsRepository!,
            settingsAIRepository: settingsAIRepository!,
            ultrasoundReportRepository: ultrasoundReportRepository!,
            ultrasoundDraftRepository: ultrasoundDraftRepository!,
            templateRepository: templateRepository!,
            subscriptionBackendRepository: subscriptionBackendRepository!,
            subscriptionStoreKitRepository: subscriptionStoreKitRepository!,
            subscriptionRepositoryFactory: subscriptionRepositoryFactory!,
            applicationConfig: applicationConfig!,
            language: language!,
            l10n: l10n!,
            examinationNeuralModelFactory: examinationNeuralModelFactory!,
            usExaminationTypeGroups: usExaminationTypeGroups!,
            usExaminationTypesById: usExaminationTypesById!,
            usExaminationTypeDefault: usExaminationTypeDefault!,
            usExaminationNeuralModels: usExaminationNeuralModels!,
            usExaminationNeuralModelsById: usExaminationNeuralModelsById!,
            usExaminationNeuralModelDefault: usExaminationNeuralModelDefault!,
            initialUserSettings: initialUserSettings!,
            initialSettingsAI: initialSettingsAI!,
            initialSubscriptionStatus: initialSubscriptionStatus,
            initialRoute: initialRoute!,
            version: version!,
        )
    }

    typealias T = DependencyContainer
}
