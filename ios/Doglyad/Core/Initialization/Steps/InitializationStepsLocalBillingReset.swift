import DependencyInitializer
import Foundation

extension InitializationProcess {
    static func stepsLocalBillingReset(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
    ) -> StepSet<InitializationProcess> {
        StepSet(
            async: [
                AsyncInitializationStep<InitializationProcess>(
                    title: "Local billing identity reset",
                    run: { @MainActor (process: InitializationProcess) async throws in
                        #if DEBUG
                            guard process.environment?.type == .development,
                                  bundleIdentifier == "com.medical.doglyad.local",
                                  arguments.contains(
                                      "--reset-local-billing-identity",
                                  )
                            else {
                                return
                            }
                            try await process.securityDatabase!.removeBillingIdentity()
                        #endif
                    },
                ),
            ],
        )
    }
}
