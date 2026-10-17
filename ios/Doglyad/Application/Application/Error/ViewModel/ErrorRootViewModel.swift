import Foundation
import UIKit

@MainActor
final class ErrorRootViewModel: DStateViewModel<any ErrorRootStateProtocol> {
    private let analytics: AnalyticsManager?

    init(
        error: Error,
        analytics: AnalyticsManager?,
    ) {
        self.analytics = analytics
        let state: any ErrorRootStateProtocol = switch error as? InitializationError {
        case .newVersion: ErrorRootNewVersionState(
                error: error,
            )
        case .noInternetConnection: ErrorRootOfflineState(
                error: error,
            )
        case .serviceUnavailable: ErrorRootServiceUnavailableState(
                error: error,
            )
        case .usExaminationTypesEmpty, .usExaminationNeuralModelsEmpty, .common, .none: ErrorRootUnknownState(
                error: error,
            )
        }
        super.init(
            state: state,
        )
    }

    func onAppear() {
        switch state {
        case _ as ErrorRootNewVersionState:
            analytics?.screenViewed(
                .newVersion,
            )
        case _ as ErrorRootOfflineState, _ as ErrorRootServiceUnavailableState, _ as ErrorRootUnknownState:
            analytics?.screenViewed(
                .initializationError,
                parameters: .initializationError(
                    state.error,
                ),
            )
        default: preconditionFailure(
                "Unexpected initialization error state",
            )
        }
    }

    func onTapRetry(
        onRetryInitialization: () -> Void = {},
    ) {
        analytics?.buttonTapped(
            .initializationRetry,
        )
        onRetryInitialization()
    }

    func onTapServiceUnavailableEmail() {
        analytics?.buttonTapped(
            .serviceUnavailableEmail,
        )

        let email: String
        switch state {
        case let state as ErrorRootServiceUnavailableState: email = state.email
        default: return
        }
        guard let encodedEmail = email.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed,
        ) else { return }
        guard let url = URL(
            string: "mailto:\(encodedEmail)",
        ) else { return }
        UIApplication.shared.open(
            url,
        )
    }

    func onTapNewVersionUpdate() {
        switch state {
        case let state as ErrorRootNewVersionState:
            analytics?.buttonTapped(
                .newVersionUpdate,
            )
            UIApplication.openAppStore(
                appleUpdateUrl: state.appleUpdateUrl,
                id: state.appStoreId,
            )
        default: break
        }
    }
}
