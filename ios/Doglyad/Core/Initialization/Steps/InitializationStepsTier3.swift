import DependencyInitializer
import DoglyadNetwork
import Foundation

extension InitializationProcess {
    static let stepsTier3 = StepSet(
        sync: [
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
