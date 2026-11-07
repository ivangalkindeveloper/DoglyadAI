import DependencyInitializer
import DoglyadNetwork
import Foundation

extension InitializationProcess {
    static let stepsTier2 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Anonymous billing identity",
                run: { (process: InitializationProcess) async throws in
                    try await process.subscriptionBackendRepository!.configureIdentity()
                },
            ),
            AsyncInitializationStep<InitializationProcess>(
                title: "Application config",
                run: { (process: InitializationProcess) async throws in
                    let preferredLanguageIdentifiers = Locale.preferredLanguages
                    let downloadedConfig: ApplicationConfig = try await process.httpClient!.get(
                        endPoint: "/application_config",
                    )
                    #if DEBUG && DOGLYAD_REGRESSION
                        let applicationConfig = try RegressionConfiguration.apply(
                            to: downloadedConfig,
                        )
                    #else
                        let applicationConfig = downloadedConfig
                    #endif
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
}
