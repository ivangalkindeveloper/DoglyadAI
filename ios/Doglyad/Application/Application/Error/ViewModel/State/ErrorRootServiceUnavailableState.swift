import Foundation

@MainActor
final class ErrorRootServiceUnavailableState: ErrorRootStateProtocol {
    let error: Error

    init(
        error: Error,
    ) {
        self.error = error
    }

    var email: String {
        switch error as? InitializationError {
        case let .serviceUnavailable(
            email,
        ): email
        case .newVersion, .noInternetConnection, .usExaminationTypesEmpty, .usExaminationNeuralModelsEmpty, .common, .none: preconditionFailure(
                "Expected serviceUnavailable",
            )
        }
    }
}
