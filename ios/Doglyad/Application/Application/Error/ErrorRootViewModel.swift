import Foundation

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
        analytics?.screenViewed(
            .initializationError,
            parameters: AnalyticsParameters([
                .error: .string(initializationErrorName),
            ])
        )
    }

    func onTapRetry() {
        analytics?.buttonTapped(.initializationRetry)
    }

    func onTapOpenSettings() {
        analytics?.buttonTapped(.initializationOpenSettings)
    }

    func onTapServiceUnavailableEmail() {
        analytics?.buttonTapped(.serviceUnavailableEmail)
    }

    private var initializationErrorName: String {
        switch error as? InitializationError {
        case .noInternetConnection:
            "no_internet_connection"
        case .noCameraRequestDenied:
            "camera_request_denied"
        case .serviceUnavailable:
            "service_unavailable"
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
