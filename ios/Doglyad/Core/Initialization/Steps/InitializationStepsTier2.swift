import DependencyInitializer
import Foundation

extension InitializationProcess {
    static let stepsTier2 = StepSet(
        async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Application config",
                run: { (process: InitializationProcess) async throws in
                    let applicationConfig: ApplicationConfig = try await process.httpClient!.get(
                        endPoint: "/application_config",
                        headers: nil
                    )
                    await MainActor.run {
                        process.applicationConfig = applicationConfig
                    }
                }
            ),
        ]
    )
}
