import DependencyInitializer
import DoglyadDatabase
import DoglyadNetwork
import FirebaseAppCheck
import FirebaseCore
import Foundation

extension InitializationProcess {
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
                    title: "Application version label",
                    run: { (process: InitializationProcess) in
                        let version = Bundle.shortVersion
                        process.version = "\(version.major).\(version.minor).\(version.patch)"
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
                            interceptors: [
                                AppCheckHttpInterceptor(),
                                BillingHttpInterceptor(
                                    baseUrl: process.environment!.baseUrl,
                                    baseVersionPrefix: process.environment!.baseVersionPrefix,
                                    securityDatabase: process.securityDatabase!,
                                ),
                            ],
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
                    title: "Subscriptions",
                    run: { (process: InitializationProcess) in
                        let backend = SubscriptionBackendRepository(
                            httpClient: process.httpClient!,
                            securityDatabase: process.securityDatabase!,
                        )
                        process.subscriptionBackendRepository = backend
                        process.subscriptionRepositoryFactory = SubscriptionRepositoryFactory(
                            storeKit: SubscriptionStoreKitRepository(
                                backend: backend,
                            ),
                            yooKassa: SubscriptionYooKassaRepository(
                                backend: backend,
                            ),
                        )
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
}
