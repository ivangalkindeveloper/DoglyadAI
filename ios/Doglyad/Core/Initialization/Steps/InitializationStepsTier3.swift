import DependencyInitializer
import DoglyadNetwork
import Foundation

extension InitializationProcess {
    static let stepsTier3 = StepSet(
        sync: [
            SyncInitializationStep<InitializationProcess>(
                title: "Service availability",
                run: { (process: InitializationProcess) in
                    let applicationConfig = process.applicationConfig!
                    guard applicationConfig.isServiceAvailable else {
                        throw InitializationError.serviceUnavailable(
                            email: applicationConfig.contactEmail
                        )
                    }
                }
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
                        appStoreId: applicationConfig.appStoreId
                    )
                }
            ),
            SyncInitializationStep<InitializationProcess>(
                title: "Network configuration",
                run: { (process: InitializationProcess) in
                    let network = process.applicationConfig!.network
                    process.httpClient!.updateConfiguration(
                        timeoutIntervalForRequest: network.timeoutIntervalForRequest,
                        timeoutIntervalForResource: network.timeoutIntervalForResource
                    )
                }
            ),
        ]
    )
}
