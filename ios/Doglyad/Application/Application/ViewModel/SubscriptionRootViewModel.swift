import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class SubscriptionRootViewModel: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    private let container: DependencyContainer
    private let getStoredNeuralModelSettings: () -> NeuralModelSettings

    init(
        container: DependencyContainer,
        getStoredNeuralModelSettings: (() -> NeuralModelSettings)? = nil,
    ) {
        self.container = container
        self.getStoredNeuralModelSettings = getStoredNeuralModelSettings ?? { container.initialNeuralModelSettings }
        status = container.initialSubscriptionStatus
        super.init()
    }

    @Published var status: SubscriptionStatus?

    func observeStatus(
        _ observer: @escaping (SubscriptionStatus?) -> Void,
    ) -> AnyCancellable {
        $status.sink(
            receiveValue: observer,
        )
    }

    var isActive: Bool {
        status != nil
    }

    var availableRequestCount: Int {
        status?.availableCountPerDay ?? 0
    }

    var formCompletionViaMicrophoneAvailability: SubscriptionFeatureAvailability {
        status?.formCompletionViaMicrophone ?? .unavailable
    }

    var sendingReportByEmailAvailability: SubscriptionFeatureAvailability {
        status?.sendingReportByEmail ?? .unavailable
    }

    var neuralModelSettingsAvailability: SubscriptionFeatureAvailability {
        status?.neuralModelSettings ?? .unavailable
    }

    func availability(
        of feature: PaidFeature,
    ) -> SubscriptionFeatureAvailability {
        status?.availability(
            of: feature,
        ) ?? .unavailable
    }

    var neuralModelSettings: NeuralModelSettings {
        let neuralModelConfig = container.applicationConfig.ultrasound.neuralModel
        let settings = getStoredNeuralModelSettings()
        switch neuralModelSettingsAvailability {
        case .available:
            return NeuralModelSettings(
                selectedNeuralModelId: settings.selectedNeuralModelId,
                isMarkdown: settings.isMarkdown,
                temperature: settings.temperature ?? neuralModelConfig.temperature,
                maxTokens: settings.maxTokens ?? neuralModelConfig.maxTokens,
            )
        case .offered, .unavailable:
            return NeuralModelSettings(
                selectedNeuralModelId: settings.selectedNeuralModelId,
                isMarkdown: false,
                temperature: neuralModelConfig.temperature,
                maxTokens: neuralModelConfig.maxTokens,
            )
        }
    }

    func refreshStatus() async {
        handle {
            try await self.container.subscriptionRepository.fetchStatus(
                configEntitlements: self.container.applicationConfig.entitlements,
            )
        } onMainSuccess: { status in
            self.status = status
        }
    }

    func incrementRequestCount() {
        handle {
            try await self.container.subscriptionRepository.incrementRequestCount(
                configEntitlements: self.container.applicationConfig.entitlements,
            )
        } onMainSuccess: { status in
            self.status = status
        }
    }

    func update(
        status: SubscriptionStatus?,
    ) {
        self.status = status
    }
}
