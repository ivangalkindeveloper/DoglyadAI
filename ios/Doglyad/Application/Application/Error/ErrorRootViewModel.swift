import Foundation
import UIKit

@MainActor
final class ErrorRootViewModel: ObservableObject {
    private let error: Error
    private let analytics: AnalyticsManager?

    init(
        error: Error,
        analytics: AnalyticsManager?
    ) {
        self.error = error
        self.analytics = analytics
    }

    func onAppear() {
        switch error as? InitializationError {
        case .newVersion:
            analytics?.screenViewed(.newVersion)
        case .noInternetConnection,
             .serviceUnavailable,
             .usExaminationTypesEmpty,
             .usExaminationNeuralModelsEmpty,
             .examinationNeuralModelPromptEmpty,
             .common,
             .none:
            analytics?.screenViewed(
                .initializationError,
                parameters: AnalyticsParameters([
                    .error: .string(initializationErrorName),
                ])
            )
        }
    }

    func onTapRetry() {
        analytics?.buttonTapped(.initializationRetry)
    }

    func onTapServiceUnavailableEmail() {
        analytics?.buttonTapped(.serviceUnavailableEmail)
    }

    func onTapNewVersionUpdate() {
        guard case let .newVersion(appleUpdateUrl, appStoreId) = error as? InitializationError else { return }

        analytics?.buttonTapped(.newVersionUpdate)
        UIApplication.openAppStore(
            appleUpdateUrl: appleUpdateUrl,
            id: appStoreId
        )
    }

    private var initializationErrorName: String {
        switch error as? InitializationError {
        case .noInternetConnection:
            "no_internet_connection"
        case .serviceUnavailable:
            "service_unavailable"
        case .newVersion:
            "new_version"
        case .usExaminationTypesEmpty:
            "examination_types_empty"
        case .usExaminationNeuralModelsEmpty:
            "neural_models_empty"
        case .examinationNeuralModelPromptEmpty:
            "neural_model_prompt_empty"
        case .common:
            "common"
        case .none:
            "unknown"
        }
    }
}
