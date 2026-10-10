import Foundation
import UIKit

@MainActor
final class ErrorRootViewModel: ObservableObject {
    private let error: Error
    private let analytics: AnalyticsManager?

    init(
        error: Error,
        analytics: AnalyticsManager?,
    ) {
        self.error = error
        self.analytics = analytics
    }

    func onAppear() {
        switch error as? InitializationError {
        case .newVersion:
            analytics?.screenViewed(
                .newVersion,
            )
        case .noInternetConnection,
             .serviceUnavailable,
             .usExaminationTypesEmpty,
             .usExaminationNeuralModelsEmpty,
             .common,
             .none:
            analytics?.screenViewed(
                .initializationError,
                parameters: .initializationError(
                    error,
                ),
            )
        }
    }

    func onTapRetry() {
        analytics?.buttonTapped(
            .initializationRetry,
        )
    }

    func onTapServiceUnavailableEmail() {
        analytics?.buttonTapped(
            .serviceUnavailableEmail,
        )

        guard case let .serviceUnavailable(
            email,
        ) = error as? InitializationError else { return }
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
        guard case let .newVersion(
            appleUpdateUrl,
            appStoreId,
        ) = error as? InitializationError else { return }

        analytics?.buttonTapped(
            .newVersionUpdate,
        )
        UIApplication.openAppStore(
            appleUpdateUrl: appleUpdateUrl,
            id: appStoreId,
        )
    }
}
