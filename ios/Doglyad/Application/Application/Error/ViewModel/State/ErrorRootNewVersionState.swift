import Foundation

@MainActor
final class ErrorRootNewVersionState: ErrorRootStateProtocol {
    let error: Error
    let appleUpdateUrl: URL
    let appStoreId: String

    init(
        error: Error,
    ) {
        self.error = error
        switch error as? InitializationError {
        case let .newVersion(
            url,
            id,
        ): appleUpdateUrl = url
            appStoreId = id
        case .noInternetConnection, .serviceUnavailable, .usExaminationTypesEmpty, .usExaminationNeuralModelsEmpty, .common, .none:
            preconditionFailure(
                "Expected a mandatory version update",
            )
        }
    }
}
