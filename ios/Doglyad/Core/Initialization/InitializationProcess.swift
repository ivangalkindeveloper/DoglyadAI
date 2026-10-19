import DependencyInitializer
import DoglyadDatabase
import DoglyadNetwork
import DoglyadNeuralModel
import FirebaseAppCheck
import FirebaseCore
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
    var subscriptionRepository: SubscriptionRepositoryProtocol?
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

    var toContainer: DependencyContainer {
        DependencyContainer(
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
            subscriptionRepository: subscriptionRepository!,
            applicationConfig: applicationConfig!,
            language: language!,
            l10n: l10n!,
            usExaminationTypeGroups: usExaminationTypeGroups!,
            usExaminationTypesById: usExaminationTypesById!,
            usExaminationTypeDefault: usExaminationTypeDefault!,
            usExaminationNeuralModels: usExaminationNeuralModels!,
            usExaminationNeuralModelsById: usExaminationNeuralModelsById!,
            usExaminationNeuralModelDefault: usExaminationNeuralModelDefault!,
            examinationNeuralModelFactory: examinationNeuralModelFactory!,
            initialSubscriptionStatus: initialSubscriptionStatus,
            initialUserSettings: initialUserSettings!,
            initialSettingsAI: initialSettingsAI!,
            initialRoute: initialRoute!,
            version: version!,
        )
    }

    typealias T = DependencyContainer
}

extension InitializationProcess {
    static let stepsTier2 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "RevenueCat configuration",
                run: { (process: InitializationProcess) async throws in
                    try await process.subscriptionRepository!.configure()
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Application config",
                run: { (process: InitializationProcess) async throws in
                    let preferredLanguageIdentifiers = Locale.preferredLanguages
                    let applicationConfig: ApplicationConfig = try await process.httpClient!.get(
                        endPoint: "/application_config",
                        headers: [DHttpHeader.acceptLanguage: preferredLanguageIdentifiers.joined(
                            separator: ", ",
                        )],
                    )
                    let language = Language(
                        localeConfig: applicationConfig.locale,
                        preferredLanguageIdentifiers: preferredLanguageIdentifiers,
                    )
                    await MainActor.run {
                        process.applicationConfig = applicationConfig
                        process.language = language
                    }
                },
            ),
        ],
    )

    static let stepsTier3 = StepSet(
        sync: [
            SyncInitializationStep<InitializationProcess>(
                title: "Service availability",
                run: { (process: InitializationProcess) in
                    let applicationConfig = process.applicationConfig!
                    guard applicationConfig.isServiceAvailable else {
                        throw InitializationError.serviceUnavailable(
                            email: applicationConfig.contactEmail,
                        )
                    }
                },
            ),
            SyncInitializationStep<InitializationProcess>(
                title: "Application version",
                run: { (process: InitializationProcess) in
                    let applicationConfig = process.applicationConfig!
                    let applicationVersion = Bundle.shortVersion
                    guard applicationVersion.major < applicationConfig.actualVersion.major,
                          !applicationConfig.appStoreId.isEmpty
                    else { return }

                    throw InitializationError.newVersion(
                        appleUpdateUrl: applicationConfig.appleUpdateUrl,
                        appStoreId: applicationConfig.appStoreId,
                    )
                },
            ),
            SyncInitializationStep<InitializationProcess>(
                title: "Network configuration",
                run: { (process: InitializationProcess) in
                    let network = process.applicationConfig!.network
                    process.httpClient!.updateConfiguration(
                        timeoutIntervalForRequest: network.timeoutIntervalForRequest,
                        timeoutIntervalForResource: network.timeoutIntervalForResource,
                    )
                },
            ),
        ],
    )

    static let stepsTier4 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "L10N",
                run: { (process: InitializationProcess) async throws in
                    let code = await process.language!.currentCode
                    let localization: Localization = try await process.httpClient!.get(
                        endPoint: "/l10n",
                        headers: [DHttpHeader.acceptLanguage: code],
                    )
                    let l10n = try L10N(
                        localization: localization,
                    )
                    await MainActor.run {
                        process.l10n = l10n
                    }
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound examination types",
                run: { (process: InitializationProcess) async throws in
                    let languageCode = await process.language!.currentCode
                    let usExaminationTypeGroups: [USExaminationTypeGroup] = try await process.httpClient!.get(
                        endPoint: "/ultrasound/examination_types",
                        headers: [DHttpHeader.acceptLanguage: languageCode],
                    )
                    guard let usExaminationTypeDefault = usExaminationTypeGroups.lazy
                        .compactMap(
                            \.examinationTypes.first,
                        )
                        .first
                    else {
                        throw InitializationError.usExaminationTypesEmpty
                    }
                    let usExaminationTypesById = Dictionary(
                        uniqueKeysWithValues: usExaminationTypeGroups
                            .flatMap(
                                \.examinationTypes,
                            )
                            .map { ($0.id, $0) },
                    )

                    await MainActor.run {
                        process.usExaminationTypeGroups = usExaminationTypeGroups
                        process.usExaminationTypesById = usExaminationTypesById
                        process.usExaminationTypeDefault = usExaminationTypeDefault
                    }
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound examination neural models",
                run: { (process: InitializationProcess) async throws in
                    let languageCode = await process.language!.currentCode
                    let usExaminationNeuralModels: [USExaminationNeuralModel] = try await process.httpClient!.get(
                        endPoint: "/ultrasound/examination_neural_models",
                        headers: [DHttpHeader.acceptLanguage: languageCode],
                    )
                    if usExaminationNeuralModels.isEmpty {
                        throw InitializationError.usExaminationNeuralModelsEmpty
                    }

                    await MainActor.run {
                        process.usExaminationNeuralModels = usExaminationNeuralModels
                        process.usExaminationNeuralModelsById = Dictionary(
                            uniqueKeysWithValues: usExaminationNeuralModels.map { ($0.id, $0) },
                        )
                        process.usExaminationNeuralModelDefault = usExaminationNeuralModels.first!
                    }
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Ultrasound dictation model factory",
                run: { (process: InitializationProcess) in
                    let config = await process.applicationConfig!.ultrasound.examinationNeuralModel
                    let locale = await process.language!.currentLocale
                    let repository = await process.ultrasoundReportRepository!

                    let parameters = DNeuralGenerationParameters(
                        temperature: config.temperature,
                        maxTokens: config.maxTokens,
                        maxContextTokens: config.maxContextTokens,
                    )

                    await MainActor.run {
                        process.examinationNeuralModelFactory = DNeuralUltrasoundModelFactory(
                            locale: locale,
                            proposalPrompt: config.proposalPrompt,
                            parameters: parameters,
                            serverTransport: repository,
                        )
                    }
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Subscription",
                run: { (process: InitializationProcess) async throws in
                    let configEntitlements = await process.applicationConfig!.entitlements
                    let status = try await process.subscriptionRepository!.fetchStatus(
                        configEntitlements: configEntitlements,
                    )
                    await MainActor.run {
                        process.initialSubscriptionStatus = status
                    }
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Initial ultrasound conclusions",
                run: { (process: InitializationProcess) async throws in
                    let count = try await process.ultrasoundReportRepository!.getReportsCount()
                    await MainActor.run {
                        process.initialUltrasoundReportsCount = count
                    }
                },
            ),
        ],
    )

    static let stepsTier5 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Stored application state",
                run: { (process: InitializationProcess) async throws in
                    try await process.prepareStoredState()
                },
            ),
        ],
    )

    static func stepsTier1(
        getIsFirebaseConfigured: @escaping () -> Bool,
        onFirebaseConfigured: @escaping () -> Void,
    ) -> StepSet<InitializationProcess> {
        StepSet(
            sync: [
                SyncInitializationStep<InitializationProcess>(
                    title: "Environment",
                    run: { (process: InitializationProcess) in
                        let type = EnvironmentType(
                            rawValue: Bundle.dictionaryString(
                                .ENVIRONMENT,
                            ),
                        ) ?? .development
                        let baseUrlString = Bundle.dictionaryString(
                            .BASE_URL,
                        )
                        let baseUrl = URL(
                            string: baseUrlString,
                        )!
                        process.environment = EnvironmentBase(
                            type: type,
                            baseUrl: baseUrl,
                        )
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Manager",
                    run: { (process: InitializationProcess) in
                        process.analytics = AnalyticsManager()
                        process.connectionManager = ConnectionManager()
                        process.connectionManager?.start()
                        process.permissionManager = PermissionManager()
                        process.mockFactory = DefaultMockFactory()
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Database",
                    run: { (process: InitializationProcess) in
                        process.database = try DDatabase()
                        process.securityDatabase = DSecurityDatabase()
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Network",
                    run: { (process: InitializationProcess) in
                        process.httpClient = DHttpClient(
                            baseUrl: process.environment!.baseUrl.absoluteString,
                            baseVersionPrefix: process.environment!.baseVersionPrefix,
                            interceptor: AppCheckHttpInterceptor(),
                        )
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Repository",
                    run: { (process: InitializationProcess) in
                        process.sharedRepository = SharedRepository(
                            database: process.database!,
                        )
                        process.settingsAIRepository = SettingsAIRepository(
                            database: process.database!,
                        )
                        process.ultrasoundReportRepository = UltrasoundReportRepository(
                            database: process.database!,
                            httpClient: process.httpClient!,
                        )
                        process.ultrasoundDraftRepository = UltrasoundDraftRepository(
                            database: process.database!,
                        )
                        process.templateRepository = TemplateRepository(
                            database: process.database!,
                            httpClient: process.httpClient!,
                        )
                        process.userSettingsRepository = UserSettingsRepository(
                            database: process.database!,
                            httpClient: process.httpClient!,
                        )
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Firebase",
                    run: { (process: InitializationProcess) in
                        if !getIsFirebaseConfigured() {
                            AppCheck.setAppCheckProviderFactory(
                                DAppCheckProviderFactory(),
                            )
                            FirebaseApp.configure()
                            onFirebaseConfigured()
                        }

                        process.analytics!.applicationOpened(
                            environment: process.environment!.type,
                            appVersion: Bundle.dictionaryString(
                                .CFBundleShortVersionString,
                            ),
                        )
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "RevenueCat",
                    run: { (process: InitializationProcess) in
                        let repository = RevenueCatSubscriptionRepository(
                            apiKey: Bundle.dictionaryString(
                                .REVENUECAT_API_KEY,
                            ),
                            environment: process.environment!,
                            securityDatabase: process.securityDatabase!,
                        )
                        process.subscriptionRepository = repository
                    },
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Internet connection",
                    run: { (process: InitializationProcess) in
                        let isConnected = process.connectionManager!.isConnected
                        if !isConnected {
                            throw InitializationError.noInternetConnection
                        }
                    },
                ),
            ],
        )
    }

    private func prepareStoredState() async throws {
        let reportRepository = ultrasoundReportRepository!
        let settingsRepository = settingsAIRepository!
        let storedSettings = try await settingsRepository.getSettings()
        let userRepository = userSettingsRepository!
        let sharedRepository = sharedRepository!
        let applicationConfig = applicationConfig!
        let availableTypeIds = Set(
            usExaminationTypesById!.keys,
        )
        let recentIds = try await reportRepository.getRecentExaminationTypeIds()
        try await reportRepository.setRecentExaminationTypeIds(
            RecentUSExaminationTypes.available(
                from: recentIds,
                availableIds: availableTypeIds,
            ),
        )
        let typeId = try await reportRepository.getSelectedExaminationTypeId()
        if let typeId, !availableTypeIds.contains(
            typeId,
        ) {
            try await reportRepository.setSelectedExaminationTypeId(
                id: usExaminationTypeDefault!.id,
            )
        }
        let selectedId = storedSettings?.selectedNeuralModelId
        var resolvedModelId = selectedId
        let selected = selectedId.flatMap { usExaminationNeuralModelsById![
            $0,
        ] }
        let isSelectionAllowed: Bool
        if let selected {
            let isAvailable = switch selected.accessibility {
            case .available: true
            case .comingSoon, .unavailable: false
            }
            let isEntitled = switch selected.entitlement {
            case .base: true
            case .pro:
                switch initialSubscriptionStatus?.type {
                case .some(
                    .pro,
                ): true
                case .some(
                    .base,
                ), .none: false
                }
            }
            isSelectionAllowed = isAvailable && isEntitled
        } else { isSelectionAllowed = false }
        if !isSelectionAllowed {
            let firstBaseModel = usExaminationNeuralModels!.first { model in
                let isAvailable = switch model.accessibility {
                case .available: true
                case .comingSoon, .unavailable: false
                }
                switch model.entitlement {
                case .base: return isAvailable
                case .pro: return false
                }
            }
            resolvedModelId = (firstBaseModel ?? usExaminationNeuralModelDefault!).id
        }
        let settings = SettingsAI(
            transcriberType: storedSettings?.transcriberType ?? .whisperKit,
            transcriptParserType: storedSettings?.transcriptParserType
                ?? (examinationNeuralModelFactory!.isFoundationModelsAvailable ? .foundationModels : .server),
            selectedNeuralModelId: resolvedModelId,
            isMarkdown: storedSettings?.isMarkdown ?? false,
            temperature: storedSettings?.temperature,
            maxTokens: storedSettings?.maxTokens,
        )
        if settings != storedSettings { try await settingsRepository.saveSettings(
            settings,
        ) }
        initialSettingsAI = settings
        initialUserSettings = try await UserSettings(
            email: userRepository.getUserEmail(),
            isRecommendationsIncluded: userRepository.getIsRecommendationsIncluded(),
            isPhotoRemarks: userRepository.getIsPhotoRemarks(),
            isDescriptionRemarks: userRepository.getIsDescriptionRemarks(),
            isRemarksVisible: userRepository.getIsRemarksVisible(),
        )
        initialRoute = try await Coordinator.initialRoute(
            for: InitialNavigationContext(
                applicationConfig: applicationConfig,
                isOnBoardingCompleted: sharedRepository.isOnBoardingCompleted(),
                selectedUSExaminationTypeId: reportRepository.getSelectedExaminationTypeId(),
                acceptedLegalDocumentDate: sharedRepository.getAcceptedLegalDocumentDate(),
                conclusionsCount: initialUltrasoundReportsCount!,
                subscriptionStatus: initialSubscriptionStatus,
            ),
        )
        let version = Bundle.shortVersion
        self.version = "\(version.major).\(version.minor).\(version.patch)"
    }
}
