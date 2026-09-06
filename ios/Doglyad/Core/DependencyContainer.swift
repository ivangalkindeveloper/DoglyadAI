import DoglyadDatabase
import DoglyadNetwork
import DoglyadNeuralModel
import Router
import SwiftData
import SwiftUI

final class DependencyContainer: ObservableObject {
    let environment: EnvironmentProtocol
    let connectionManager: ConnectionManagerProtocol
    let permissionManager: PermissionManagerProtocol
    let mockFactory: MockFactory
    let sharedRepository: SharedRepositoryProtocol
    let userSettingsRepository: UserSettingsRepositoryProtocol
    let ultrasoundModelRepository: UltrasoundModelRepositoryProtocol
    let ultrasoundConclusionRepository: UltrasoundConclusionRepositoryProtocol
    let templateRepository: TemplateRepositoryProtocol
    let subscriptionRepository: RevenueCatSubscriptionRepository
    let applicationConfig: ApplicationConfig
    let examinationNeuralModelFactory: DExaminationNeuralModelFactory?
    let usExaminationTypes: [USExaminationType]
    let usExaminationTypesById: [String: USExaminationType]
    let usExaminationTypeDefault: USExaminationType
    let usExaminationNeuralModels: [USExaminationNeuralModel]
    let usExaminationNeuralModelsById: [String: USExaminationNeuralModel]
    let usExaminationNeuralModelDefault: USExaminationNeuralModel
    let usExaminationContextualStrings: USExaminationContextualStrings
    let initialSubscriptionStatus: SubscriptionStatus?
    let initialRoute: RouteScreen<ScreenType>
    let version: String

    init(
        environment: EnvironmentProtocol,
        connectionManager: ConnectionManagerProtocol,
        permissionManager: PermissionManagerProtocol,
        mockFactory: MockFactory,
        sharedRepository: SharedRepositoryProtocol,
        userSettingsRepository: UserSettingsRepositoryProtocol,
        ultrasoundModelRepository: UltrasoundModelRepositoryProtocol,
        ultrasoundConclusionRepository: UltrasoundConclusionRepositoryProtocol,
        templateRepository: TemplateRepositoryProtocol,
        subscriptionRepository: RevenueCatSubscriptionRepository,
        applicationConfig: ApplicationConfig,
        usExaminationTypes: [USExaminationType],
        usExaminationTypesById: [String: USExaminationType],
        usExaminationTypeDefault: USExaminationType,
        usExaminationNeuralModels: [USExaminationNeuralModel],
        usExaminationNeuralModelsById: [String: USExaminationNeuralModel],
        usExaminationNeuralModelDefault: USExaminationNeuralModel,
        usExaminationContextualStrings: USExaminationContextualStrings,
        examinationNeuralModelFactory: DExaminationNeuralModelFactory?,
        initialSubscriptionStatus: SubscriptionStatus?,
        initialRoute: RouteScreen<ScreenType>,
        version: String
    ) {
        self.environment = environment
        self.connectionManager = connectionManager
        self.permissionManager = permissionManager
        self.mockFactory = mockFactory
        self.sharedRepository = sharedRepository
        self.userSettingsRepository = userSettingsRepository
        self.ultrasoundModelRepository = ultrasoundModelRepository
        self.ultrasoundConclusionRepository = ultrasoundConclusionRepository
        self.templateRepository = templateRepository
        self.subscriptionRepository = subscriptionRepository
        self.applicationConfig = applicationConfig
        self.usExaminationTypes = usExaminationTypes
        self.usExaminationTypesById = usExaminationTypesById
        self.usExaminationTypeDefault = usExaminationTypeDefault
        self.usExaminationNeuralModels = usExaminationNeuralModels
        self.usExaminationNeuralModelsById = usExaminationNeuralModelsById
        self.usExaminationNeuralModelDefault = usExaminationNeuralModelDefault
        self.usExaminationContextualStrings = usExaminationContextualStrings
        self.examinationNeuralModelFactory = examinationNeuralModelFactory
        self.initialSubscriptionStatus = initialSubscriptionStatus
        self.initialRoute = initialRoute
        self.version = version
    }
}

extension DependencyContainer {
    var isUSExaminationNeuralModelAvailable: Bool {
        examinationNeuralModelFactory?.isAvailable ?? false
    }

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

    func getContextualStrings(
        for locale: Locale
    ) -> [String] {
        usExaminationContextualStrings.getStrings(for: locale)
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
        let ultrasoundConclusionRepository = UltrasoundConclusionRepository(
            database: database,
            httpClient: httpClient
        )
        let templateRepository = TemplateRepository(
            database: database
        )
        let subscriptionRepository = RevenueCatSubscriptionRepository(
            apiKey: "",
            environment: environment,
            securityDatabase: DSecurityDatabase()
        )

        return DependencyContainer(
            environment: environment,
            connectionManager: ConnectionManager(),
            permissionManager: PermissionManager(),
            mockFactory: DefaultMockFactory(),
            sharedRepository: sharedRepository,
            userSettingsRepository: userSettingsRepository,
            ultrasoundModelRepository: ultrasoundModelRepository,
            ultrasoundConclusionRepository: ultrasoundConclusionRepository,
            templateRepository: templateRepository,
            subscriptionRepository: subscriptionRepository,
            applicationConfig: .default,
            usExaminationTypes: [],
            usExaminationTypesById: [:],
            usExaminationTypeDefault: .init(
                id: "",
                title: [:]
            ),
            usExaminationNeuralModels: [],
            usExaminationNeuralModelsById: [:],
            usExaminationNeuralModelDefault: .init(
                id: "",
                title: "",
                entitlement: .base,
                accessibility: .available,
                contextLength: 0,
                description: [:]
            ),
            usExaminationContextualStrings: .init(strings: [:]),
            examinationNeuralModelFactory: nil,
            initialSubscriptionStatus: nil,
            initialRoute: RouteScreen(type: .onBoarding),
            version: "1.0.0"
        )
    }
}
