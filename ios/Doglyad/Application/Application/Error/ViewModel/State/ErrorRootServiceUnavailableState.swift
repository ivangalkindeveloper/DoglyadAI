import Foundation

@MainActor
final class ErrorRootServiceUnavailableState: ErrorRootStateProtocol, @MainActor Equatable {
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

    static func == (
        lhs: ErrorRootServiceUnavailableState,
        rhs: ErrorRootServiceUnavailableState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
    }
}
