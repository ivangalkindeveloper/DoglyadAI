import DependencyInitializer
import DoglyadDatabase
import DoglyadNetwork
import DoglyadNeuralModel
import Router

@MainActor
final class InitializationProcess: DependencyInitializationProcess {
    typealias T = DependencyContainer

    var analytics: AnalyticsManager?
    var environment: EnvironmentProtocol?
    var connectionManager: ConnectionManagerProtocol?
    var permissionManager: PermissionManagerProtocol?
    var mockFactory: MockFactory?
    var database: DDatabase?
    var securityDatabase: DSecurityDatabaseProtocol?
    var httpClient: DHttpClientProtocol?
    var sharedRepository: SharedRepositoryProtocol?
    var userSettingsRepository: UserSettingsRepositoryProtocol?
    var ultrasoundModelRepository: UltrasoundModelRepositoryProtocol?
    var ultrasoundReportRepository: UltrasoundReportRepositoryProtocol?
    var ultrasoundDraftRepository: UltrasoundDraftRepositoryProtocol?
    var templateRepository: TemplateRepositoryProtocol?
    var subscriptionRepository: RevenueCatSubscriptionRepository?
    var applicationConfig: ApplicationConfig?
    var usExaminationTypeGroups: [USExaminationTypeGroup]?
    var usExaminationTypesById: [String: USExaminationType]?
    var usExaminationTypeDefault: USExaminationType?
    var usExaminationNeuralModels: [USExaminationNeuralModel]?
    var usExaminationNeuralModelsById: [String: USExaminationNeuralModel]?
    var usExaminationNeuralModelDefault: USExaminationNeuralModel?
    var usExaminationContextualStrings: USExaminationContextualStrings?
    var examinationNeuralModelFactory: DExaminationNeuralModelFactory?
    var initialUltrasoundReportsCount: Int?
    var initialSubscriptionStatus: SubscriptionStatus?
    var initialRoute: RouteScreen<ScreenType>?
    var version: String?

    var toContainer: DependencyContainer {
        DependencyContainer(
            analytics: analytics!,
            environment: environment!,
            connectionManager: connectionManager!,
            permissionManager: permissionManager!,
            mockFactory: mockFactory!,
            sharedRepository: sharedRepository!,
            userSettingsRepository: userSettingsRepository!,
            ultrasoundModelRepository: ultrasoundModelRepository!,
            ultrasoundReportRepository: ultrasoundReportRepository!,
            ultrasoundDraftRepository: ultrasoundDraftRepository!,
            templateRepository: templateRepository!,
            subscriptionRepository: subscriptionRepository!,
            applicationConfig: applicationConfig!,
            usExaminationTypeGroups: usExaminationTypeGroups!,
            usExaminationTypesById: usExaminationTypesById!,
            usExaminationTypeDefault: usExaminationTypeDefault!,
            usExaminationNeuralModels: usExaminationNeuralModels!,
            usExaminationNeuralModelsById: usExaminationNeuralModelsById!,
            usExaminationNeuralModelDefault: usExaminationNeuralModelDefault!,
            usExaminationContextualStrings: usExaminationContextualStrings!,
            examinationNeuralModelFactory: examinationNeuralModelFactory,
            initialSubscriptionStatus: initialSubscriptionStatus,
            initialRoute: initialRoute!,
            version: version!
        )
    }
}
