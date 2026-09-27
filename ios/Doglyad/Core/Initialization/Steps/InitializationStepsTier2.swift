import DependencyInitializer
import DoglyadNetwork
import Foundation

extension InitializationProcess {
    static let stepsTier2 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Application config",
                run: { (process: InitializationProcess) async throws in
                    let preferredLanguageIdentifiers = Locale.preferredLanguages
                    let applicationConfig: ApplicationConfig = try await process.httpClient!.get(
                        endPoint: "/application_config",
                        headers: [DHttpHeader.acceptLanguage: preferredLanguageIdentifiers.joined(separator: ", ")]
                    )
                    let language = Language(
                        localeConfig: applicationConfig.locale,
                        preferredLanguageIdentifiers: preferredLanguageIdentifiers
                    )
                    await MainActor.run {
                        process.applicationConfig = applicationConfig
                        process.language = language
                    }
                }
            ),
        ]
    )
}
