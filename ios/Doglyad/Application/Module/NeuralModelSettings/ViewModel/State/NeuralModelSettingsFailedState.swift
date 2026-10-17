import Foundation

@MainActor
final class NeuralModelSettingsFailedState: NeuralModelSettingsStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }
}
