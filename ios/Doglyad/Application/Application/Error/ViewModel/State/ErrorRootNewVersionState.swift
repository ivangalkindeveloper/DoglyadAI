import Foundation

@MainActor
final class ErrorRootNewVersionState: ErrorRootStateProtocol, @MainActor Equatable {
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

    static func == (
        lhs: ErrorRootNewVersionState,
        rhs: ErrorRootNewVersionState,
    ) -> Bool {
        lhs === rhs || lhs.error.isEqual(
            to: rhs.error,
        )
            && lhs.appleUpdateUrl == rhs.appleUpdateUrl
            && lhs.appStoreId == rhs.appStoreId
    }
}
