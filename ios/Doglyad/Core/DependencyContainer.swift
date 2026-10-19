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
    let mockFactory: MockFactoryProtocol
    let sharedRepository: SharedRepositoryProtocol
    let userSettingsRepository: UserSettingsRepositoryProtocol
    let settingsAIRepository: SettingsAIRepositoryProtocol
    let ultrasoundReportRepository: UltrasoundReportRepositoryProtocol
    let ultrasoundDraftRepository: UltrasoundDraftRepositoryProtocol
    let templateRepository: TemplateRepositoryProtocol
    let subscriptionRepository: SubscriptionRepositoryProtocol
    let applicationConfig: ApplicationConfig
    let language: Language
    let l10n: L10N
    let examinationNeuralModelFactory: DNeuralUltrasoundModelFactory
    let usExaminationTypeGroups: [USExaminationTypeGroup]
    let usExaminationTypesById: [String: USExaminationType]
    let usExaminationTypeDefault: USExaminationType
    let usExaminationNeuralModels: [USExaminationNeuralModel]
    let usExaminationNeuralModelsById: [String: USExaminationNeuralModel]
    let usExaminationNeuralModelDefault: USExaminationNeuralModel
    let initialUserSettings: UserSettings
    let initialSettingsAI: SettingsAI
    let initialSubscriptionStatus: SubscriptionStatus?
    let initialRoute: RouteScreen<ScreenType>
    let version: String

    init(
        analytics: AnalyticsManager,
        environment: EnvironmentProtocol,
        connectionManager: ConnectionManagerProtocol,
        permissionManager: PermissionManagerProtocol,
        mockFactory: MockFactoryProtocol,
        sharedRepository: SharedRepositoryProtocol,
        userSettingsRepository: UserSettingsRepositoryProtocol,
        settingsAIRepository: SettingsAIRepositoryProtocol,
        ultrasoundReportRepository: UltrasoundReportRepositoryProtocol,
        ultrasoundDraftRepository: UltrasoundDraftRepositoryProtocol,
        templateRepository: TemplateRepositoryProtocol,
        subscriptionRepository: SubscriptionRepositoryProtocol,
        applicationConfig: ApplicationConfig,
        language: Language,
        l10n: L10N,
        usExaminationTypeGroups: [USExaminationTypeGroup],
        usExaminationTypesById: [String: USExaminationType],
        usExaminationTypeDefault: USExaminationType,
        usExaminationNeuralModels: [USExaminationNeuralModel],
        usExaminationNeuralModelsById: [String: USExaminationNeuralModel],
        usExaminationNeuralModelDefault: USExaminationNeuralModel,
        examinationNeuralModelFactory: DNeuralUltrasoundModelFactory,
        initialSubscriptionStatus: SubscriptionStatus?,
        initialUserSettings: UserSettings = .initial,
        initialSettingsAI: SettingsAI? = nil,
        initialRoute: RouteScreen<ScreenType>,
        version: String,
    ) {
        self.analytics = analytics
        self.environment = environment
        self.connectionManager = connectionManager
        self.permissionManager = permissionManager
        self.mockFactory = mockFactory
        self.sharedRepository = sharedRepository
        self.userSettingsRepository = userSettingsRepository
        self.settingsAIRepository = settingsAIRepository
        self.ultrasoundReportRepository = ultrasoundReportRepository
        self.ultrasoundDraftRepository = ultrasoundDraftRepository
        self.templateRepository = templateRepository
        self.subscriptionRepository = subscriptionRepository
        self.applicationConfig = applicationConfig
        self.language = language
        self.l10n = l10n
        self.usExaminationTypeGroups = usExaminationTypeGroups
        self.usExaminationTypesById = usExaminationTypesById
        self.usExaminationTypeDefault = usExaminationTypeDefault
        self.usExaminationNeuralModels = usExaminationNeuralModels
        self.usExaminationNeuralModelsById = usExaminationNeuralModelsById
        self.usExaminationNeuralModelDefault = usExaminationNeuralModelDefault
        self.examinationNeuralModelFactory = examinationNeuralModelFactory
        self.initialUserSettings = initialUserSettings
        self.initialSettingsAI = initialSettingsAI ?? SettingsAI(
            selectedNeuralModelId: usExaminationNeuralModelDefault.id,
            isMarkdown: false,
            temperature: applicationConfig.ultrasound.neuralModel.temperature,
            maxTokens: applicationConfig.ultrasound.neuralModel.maxTokens,
        )
        self.initialSubscriptionStatus = initialSubscriptionStatus
        self.initialRoute = initialRoute
        self.version = version
    }
}

extension DependencyContainer {
    func getUSExaminationTypeById(
        id: String,
    ) -> USExaminationType? {
        usExaminationTypesById[
            id,
        ]
    }

    func getUSExaminationNeuralModelById(
        id: String,
    ) -> USExaminationNeuralModel? {
        usExaminationNeuralModelsById[
            id,
        ]
    }
}

extension DependencyContainer {
    @MainActor
    static var previewable: DependencyContainer {
        makePreviewable()
    }

    @MainActor
    static func makePreviewable(
        l10n: L10N? = nil,
    ) -> DependencyContainer {
        let environment = EnvironmentBase(
            type: .development,
            baseUrl: URL(
                filePath: "",
            )!,
        )
        let database = try! DDatabase()
        let httpClient = DHttpClient(
            baseUrl: environment.baseUrl.absoluteString,
            baseVersionPrefix: environment.baseVersionPrefix,
        )
        let sharedRepository = SharedRepository(
            database: database,
        )
        let userSettingsRepository = UserSettingsRepository(
            database: database,
            httpClient: httpClient,
        )
        let settingsAIRepository = SettingsAIRepository(
            database: database,
        )
        let ultrasoundReportRepository = UltrasoundReportRepository(
            database: database,
            httpClient: httpClient,
        )
        let ultrasoundDraftRepository = UltrasoundDraftRepository(
            database: database,
        )
        let templateRepository = TemplateRepository(
            database: database,
            httpClient: httpClient,
        )
        let subscriptionRepository = RevenueCatSubscriptionRepository(
            apiKey: "",
            environment: environment,
            securityDatabase: DSecurityDatabase(),
        )
        let applicationConfig = ApplicationConfig.default
        let language = Language(
            localeConfig: applicationConfig.locale,
            preferredLanguageIdentifiers: l10n.map { [$0.locale.identifier] } ?? Locale.preferredLanguages,
        )

        return DependencyContainer(
            analytics: AnalyticsManager(
                isEnabled: false,
            ),
            environment: environment,
            connectionManager: ConnectionManager(),
            permissionManager: PermissionManager(),
            mockFactory: DefaultMockFactory(),
            sharedRepository: sharedRepository,
            userSettingsRepository: userSettingsRepository,
            settingsAIRepository: settingsAIRepository,
            ultrasoundReportRepository: ultrasoundReportRepository,
            ultrasoundDraftRepository: ultrasoundDraftRepository,
            templateRepository: templateRepository,
            subscriptionRepository: subscriptionRepository,
            applicationConfig: applicationConfig,
            language: language,
            l10n: l10n ?? L10N.previewable(
                code: language.currentCode,
            ),
            usExaminationTypeGroups: [],
            usExaminationTypesById: [:],
            usExaminationTypeDefault: .init(
                id: "",
                title: "",
                contextualStrings: [],
            ),
            usExaminationNeuralModels: [],
            usExaminationNeuralModelsById: [:],
            usExaminationNeuralModelDefault: .init(
                id: "",
                title: "",
                entitlement: .base,
                accessibility: .available,
                contextLength: 0,
                description: "",
            ),
            examinationNeuralModelFactory: DNeuralUltrasoundModelFactory(
                locale: language.currentLocale,
                proposalPrompt: applicationConfig.ultrasound.examinationNeuralModel.proposalPrompt,
                parameters: DNeuralGenerationParameters(
                    temperature: applicationConfig.ultrasound.examinationNeuralModel.temperature,
                    maxTokens: applicationConfig.ultrasound.examinationNeuralModel.maxTokens,
                    maxContextTokens: applicationConfig.ultrasound.examinationNeuralModel.maxContextTokens,
                ),
                serverTransport: ultrasoundReportRepository,
            ),
            initialSubscriptionStatus: nil,
            initialRoute: RouteScreen(
                type: .onBoarding,
            ),
            version: "1.0.0",
        )
    }
}
