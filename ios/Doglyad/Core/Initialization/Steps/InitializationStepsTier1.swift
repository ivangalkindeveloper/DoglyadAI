import DependencyInitializer
import DoglyadDatabase
import DoglyadNetwork
import FirebaseAppCheck
import FirebaseCore
import Foundation

extension InitializationProcess {
    static func stepsTier1(
        getIsFirebaseConfigured: @escaping () -> Bool,
        onFirebaseConfigured: @escaping () -> Void
    ) -> StepSet<InitializationProcess> {
        StepSet(
            sync: [
                SyncInitializationStep<InitializationProcess>(
                    title: "Environment",
                    run: { (process: InitializationProcess) in
                        let type = EnvironmentType(rawValue: Bundle.dictionaryString(.ENVIRONMENT)) ?? .development
                        let baseUrlString = Bundle.dictionaryString(.BASE_URL)
                        let baseUrl = URL(string: baseUrlString)!
                        process.environment = EnvironmentBase(
                            type: type,
                            baseUrl: baseUrl
                        )
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Manager",
                    run: { (process: InitializationProcess) in
                        process.connectionManager = ConnectionManager()
                        process.connectionManager?.start()
                        process.permissionManager = PermissionManager()
                        process.mockFactory = DefaultMockFactory()
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Database",
                    run: { (process: InitializationProcess) in
                        process.database = try DDatabase()
                        process.securityDatabase = DSecurityDatabase()
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Network",
                    run: { (process: InitializationProcess) in
                        process.httpClient = DHttpClient(
                            baseUrl: process.environment!.baseUrl.absoluteString,
                            baseVersionPrefix: process.environment!.baseVersionPrefix,
                            interceptor: AppCheckHttpInterceptor()
                        )
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Repository",
                    run: { (process: InitializationProcess) in
                        process.sharedRepository = SharedRepository(
                            database: process.database!
                        )
                        process.ultrasoundModelRepository = UltrasoundModelRepository(
                            database: process.database!
                        )
                        process.ultrasoundConclusionRepository = UltrasoundConclusionRepository(
                            database: process.database!,
                            httpClient: process.httpClient!
                        )
                        process.templateRepository = TemplateRepository(
                            database: process.database!
                        )
                        process.userSettingsRepository = UserSettingsRepository(
                            database: process.database!,
                            httpClient: process.httpClient!
                        )
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Firebase",
                    run: { (_: InitializationProcess) in
                        guard !getIsFirebaseConfigured() else { return }

                        AppCheck.setAppCheckProviderFactory(DAppCheckProviderFactory())
                        FirebaseApp.configure()
                        onFirebaseConfigured()
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "RevenueCat",
                    run: { (process: InitializationProcess) in
                        let repository = RevenueCatSubscriptionRepository(
                            apiKey: Bundle.dictionaryString(.REVENUECAT_API_KEY),
                            environment: process.environment!,
                            securityDatabase: process.securityDatabase!
                        )
                        repository.configure()
                        process.subscriptionRepository = repository
                    }
                ),
                SyncInitializationStep<InitializationProcess>(
                    title: "Internet connection",
                    run: { (process: InitializationProcess) in
                        let isConnected = process.connectionManager!.isConnected
                        if !isConnected {
                            throw InitializationError.noInternetConnection
                        }
                    }
                ),
            ]
        )
    }
}
