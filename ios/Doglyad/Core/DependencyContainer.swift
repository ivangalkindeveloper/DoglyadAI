import DoglyadDatabase
import DoglyadNetwork
import DoglyadNeuralModel
import Router
import SwiftData
import SwiftUI

final class DependencyContainer: ObservableObject {
    let analytics: AnalyticsManager
    let environment: EnvironmentProtocol
    let connectionManager: ConnectionManagerProtocol
    let permissionManager: PermissionManagerProtocol
    let mockFactory: MockFactory
    let sharedRepository: SharedRepositoryProtocol
    let userSettingsRepository: UserSettingsRepositoryProtocol
    let ultrasoundModelRepository: UltrasoundModelRepositoryProtocol
    let ultrasoundReportRepository: UltrasoundReportRepositoryProtocol
    let ultrasoundDraftRepository: UltrasoundDraftRepositoryProtocol
    let templateRepository: TemplateRepositoryProtocol
    let subscriptionRepository: RevenueCatSubscriptionRepository
    let applicationConfig: ApplicationConfig
    let language: Language
    let examinationNeuralModelFactory: DExaminationNeuralModelFactory?
    let usExaminationTypeGroups: [USExaminationTypeGroup]
    let usExaminationTypesById: [String: USExaminationType]
    let usExaminationTypeDefault: USExaminationType
    let usExaminationNeuralModels: [USExaminationNeuralModel]
    let usExaminationNeuralModelsById: [String: USExaminationNeuralModel]
    let usExaminationNeuralModelDefault: USExaminationNeuralModel
    let initialSubscriptionStatus: SubscriptionStatus?
    let initialRoute: RouteScreen<ScreenType>
    let version: String

    init(
        analytics: AnalyticsManager,
        environment: EnvironmentProtocol,
        connectionManager: ConnectionManagerProtocol,
        permissionManager: PermissionManagerProtocol,
        mockFactory: MockFactory,
        sharedRepository: SharedRepositoryProtocol,
        userSettingsRepository: UserSettingsRepositoryProtocol,
        ultrasoundModelRepository: UltrasoundModelRepositoryProtocol,
        ultrasoundReportRepository: UltrasoundReportRepositoryProtocol,
        ultrasoundDraftRepository: UltrasoundDraftRepositoryProtocol,
        templateRepository: TemplateRepositoryProtocol,
        subscriptionRepository: RevenueCatSubscriptionRepository,
        applicationConfig: ApplicationConfig,
        language: Language,
        usExaminationTypeGroups: [USExaminationTypeGroup],
        usExaminationTypesById: [String: USExaminationType],
        usExaminationTypeDefault: USExaminationType,
        usExaminationNeuralModels: [USExaminationNeuralModel],
        usExaminationNeuralModelsById: [String: USExaminationNeuralModel],
        usExaminationNeuralModelDefault: USExaminationNeuralModel,
        examinationNeuralModelFactory: DExaminationNeuralModelFactory?,
        initialSubscriptionStatus: SubscriptionStatus?,
        initialRoute: RouteScreen<ScreenType>,
        version: String
    ) {
        self.analytics = analytics
        self.environment = environment
        self.connectionManager = connectionManager
        self.permissionManager = permissionManager
        self.mockFactory = mockFactory
        self.sharedRepository = sharedRepository
        self.userSettingsRepository = userSettingsRepository
        self.ultrasoundModelRepository = ultrasoundModelRepository
        self.ultrasoundReportRepository = ultrasoundReportRepository
        self.ultrasoundDraftRepository = ultrasoundDraftRepository
        self.templateRepository = templateRepository
        self.subscriptionRepository = subscriptionRepository
        self.applicationConfig = applicationConfig
        self.language = language
        self.usExaminationTypeGroups = usExaminationTypeGroups
        self.usExaminationTypesById = usExaminationTypesById
        self.usExaminationTypeDefault = usExaminationTypeDefault
        self.usExaminationNeuralModels = usExaminationNeuralModels
        self.usExaminationNeuralModelsById = usExaminationNeuralModelsById
        self.usExaminationNeuralModelDefault = usExaminationNeuralModelDefault
        self.examinationNeuralModelFactory = examinationNeuralModelFactory
        self.initialSubscriptionStatus = initialSubscriptionStatus
        self.initialRoute = initialRoute
        self.version = version
    }
}

extension DependencyContainer {
    func getUSExaminationTypeById(
        id: String
    ) -> USExaminationType? {
        usExaminationTypesById[id]
    }

    func getUSExaminationNeuralModelById(
        id: String
    ) -> USExaminationNeuralModel? {
        usExaminationNeuralModelsById[id]
    }
}

extension DependencyContainer {
    @MainActor
    static var previewable: DependencyContainer {
        let environment = EnvironmentBase(
            type: .development,
            baseUrl: URL(filePath: "")!
        )
        let database = try! DDatabase()
        let httpClient = DHttpClient(
            baseUrl: environment.baseUrl.absoluteString,
            baseVersionPrefix: environment.baseVersionPrefix
        )
        let sharedRepository = SharedRepository(
            database: database
        )
        let userSettingsRepository = UserSettingsRepository(
            database: database,
            httpClient: httpClient
        )
        let ultrasoundModelRepository = UltrasoundModelRepository(
            database: database
        )
        let ultrasoundReportRepository = UltrasoundReportRepository(
            database: database,
            httpClient: httpClient
        )
        let ultrasoundDraftRepository = UltrasoundDraftRepository(
            database: database
        )
        let templateRepository = TemplateRepository(
            database: database,
            httpClient: httpClient
        )
        let subscriptionRepository = RevenueCatSubscriptionRepository(
            apiKey: "",
            environment: environment,
            securityDatabase: DSecurityDatabase()
        )
        let applicationConfig = ApplicationConfig.default
        let language = Language(
            localeConfig: applicationConfig.locale,
            preferredLanguageIdentifiers: Locale.preferredLanguages
        )

        return DependencyContainer(
            analytics: AnalyticsManager(isEnabled: false),
            environment: environment,
            connectionManager: ConnectionManager(),
            permissionManager: PermissionManager(),
            mockFactory: DefaultMockFactory(),
            sharedRepository: sharedRepository,
            userSettingsRepository: userSettingsRepository,
            ultrasoundModelRepository: ultrasoundModelRepository,
            ultrasoundReportRepository: ultrasoundReportRepository,
            ultrasoundDraftRepository: ultrasoundDraftRepository,
            templateRepository: templateRepository,
            subscriptionRepository: subscriptionRepository,
            applicationConfig: applicationConfig,
            language: language,
            usExaminationTypeGroups: [],
            usExaminationTypesById: [:],
            usExaminationTypeDefault: .init(
                id: "",
                title: "",
                contextualStrings: []
            ),
            usExaminationNeuralModels: [],
            usExaminationNeuralModelsById: [:],
            usExaminationNeuralModelDefault: .init(
                id: "",
                title: "",
                entitlement: .base,
                accessibility: .available,
                contextLength: 0,
                description: ""
            ),
            examinationNeuralModelFactory: nil,
            initialSubscriptionStatus: nil,
            initialRoute: RouteScreen(type: .onBoarding),
            version: "1.0.0"
        )
    }
}
