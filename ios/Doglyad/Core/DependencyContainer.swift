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
    let subscriptionBackendRepository: SubscriptionBackendRepositoryProtocol
    let subscriptionRepositoryFactory: SubscriptionRepositoryFactory
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
        subscriptionBackendRepository: SubscriptionBackendRepositoryProtocol,
        subscriptionRepositoryFactory: SubscriptionRepositoryFactory,
        applicationConfig: ApplicationConfig,
        language: Language,
        l10n: L10N,
        examinationNeuralModelFactory: DNeuralUltrasoundModelFactory,
        usExaminationTypeGroups: [USExaminationTypeGroup],
        usExaminationTypesById: [String: USExaminationType],
        usExaminationTypeDefault: USExaminationType,
        usExaminationNeuralModels: [USExaminationNeuralModel],
        usExaminationNeuralModelsById: [String: USExaminationNeuralModel],
        usExaminationNeuralModelDefault: USExaminationNeuralModel,
        initialUserSettings: UserSettings = .initial,
        initialSettingsAI: SettingsAI? = nil,
        initialSubscriptionStatus: SubscriptionStatus?,
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
        self.subscriptionBackendRepository = subscriptionBackendRepository
        self.subscriptionRepositoryFactory = subscriptionRepositoryFactory
        self.applicationConfig = applicationConfig
        self.language = language
        self.l10n = l10n
        self.examinationNeuralModelFactory = examinationNeuralModelFactory
        self.usExaminationTypeGroups = usExaminationTypeGroups
        self.usExaminationTypesById = usExaminationTypesById
        self.usExaminationTypeDefault = usExaminationTypeDefault
        self.usExaminationNeuralModels = usExaminationNeuralModels
        self.usExaminationNeuralModelsById = usExaminationNeuralModelsById
        self.usExaminationNeuralModelDefault = usExaminationNeuralModelDefault
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
        #if DEBUG
            makePreviewable(
                l10n: L10NPreviewFactory.make(),
            )
        #else
            makePreviewable()
        #endif
    }

    @MainActor
    static func makePreviewable(
        l10n: L10N? = nil,
        subscriptionRepositoryFactory: SubscriptionRepositoryFactory? = nil,
        usExaminationTypesById: [String: USExaminationType]? = nil,
        usExaminationTypeGroups: [USExaminationTypeGroup]? = nil,
        usExaminationNeuralModels: [USExaminationNeuralModel]? = nil,
    ) -> DependencyContainer {
        #if DEBUG
            let fixtures = DevelopmentPreviewFactory.make(
                code: l10n?.locale.language.languageCode?.identifier ?? "ru",
            )
            let applicationConfig = fixtures.application
            let l10n = l10n ?? (try! L10N(
                localization: fixtures.localization,
            ))
            let usExaminationTypeGroups = usExaminationTypeGroups ?? fixtures.examinationTypes
            let usExaminationNeuralModels = usExaminationNeuralModels ?? fixtures.neuralModels
        #else
            let applicationConfig = ApplicationConfig.default
            let l10n = l10n ?? L10N.previewable(
                code: "ru",
            )
            let usExaminationTypeGroups = usExaminationTypeGroups ?? []
            let usExaminationNeuralModels = usExaminationNeuralModels ?? []
        #endif
        let usExaminationTypesById = usExaminationTypesById ?? Dictionary(
            uniqueKeysWithValues: usExaminationTypeGroups.flatMap(
                \.examinationTypes,
            ).map {
                ($0.id, $0)
            },
        )
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
        let subscriptionBackendRepository = SubscriptionBackendRepository(
            httpClient: httpClient,
            securityDatabase: DSecurityDatabase(),
        )
        let subscriptionRepositoryFactory = subscriptionRepositoryFactory ?? SubscriptionRepositoryFactory(
            storeKit: SubscriptionStoreKitRepository(
                backend: subscriptionBackendRepository,
            ),
            yooKassa: SubscriptionYooKassaRepository(
                backend: subscriptionBackendRepository,
            ),
        )
        let language = Language(
            localeConfig: applicationConfig.locale,
            preferredLanguageIdentifiers: [l10n.locale.identifier],
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
            subscriptionBackendRepository: subscriptionBackendRepository,
            subscriptionRepositoryFactory: subscriptionRepositoryFactory,
            applicationConfig: applicationConfig,
            language: language,
            l10n: l10n,
            examinationNeuralModelFactory: DNeuralUltrasoundModelFactory(
                locale: language.currentLocale,
                proposalPrompt: applicationConfig.ultrasound.examinationNeuralModel.proposalPrompt,
                parameters: DNeuralGenerationParameters(
                    temperature: applicationConfig.ultrasound.examinationNeuralModel.temperature,
                    maxTokens: applicationConfig.ultrasound.examinationNeuralModel.maxTokens,
                    maxContextTokens: applicationConfig.ultrasound.examinationNeuralModel.maxContextTokens,
                ),
                parseDictation: ultrasoundReportRepository.parseDictation,
            ),
            usExaminationTypeGroups: usExaminationTypeGroups,
            usExaminationTypesById: usExaminationTypesById,
            usExaminationTypeDefault: usExaminationTypeGroups.first?.examinationTypes.first ?? .init(
                id: "",
                title: "",
                contextualStrings: [],
            ),
            usExaminationNeuralModels: usExaminationNeuralModels,
            usExaminationNeuralModelsById: Dictionary(
                uniqueKeysWithValues: usExaminationNeuralModels.map {
                    ($0.id, $0)
                },
            ),
            usExaminationNeuralModelDefault: usExaminationNeuralModels.first ?? .init(
                id: "",
                title: "",
                entitlement: .base,
                accessibility: .available,
                contextLength: 0,
                description: "",
            ),
            initialSubscriptionStatus: nil,
            initialRoute: RouteScreen(
                type: .onBoarding,
            ),
            version: "1.0.0",
        )
    }
}
