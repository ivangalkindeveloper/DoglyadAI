import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class SubscriptionViewModel: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    private let container: DependencyContainer

    init(
        container: DependencyContainer
    ) {
        self.container = container
        status = container.initialSubscriptionStatus
        super.init()
    }

    @Published var status: SubscriptionStatus?

    var isActive: Bool {
        status != nil
    }

    var availableRequestCount: Int {
        status?.availableCountPerDay ?? 0
    }

    var formCompletionViaMicrophoneAvailability: SubscriptionFeatureAvailability {
        status?.formCompletionViaMicrophone ?? .unavailable
    }

    var sendingConclusionByEmailAvailability: SubscriptionFeatureAvailability {
        status?.sendingConclusionByEmail ?? .unavailable
    }

    var neuralModelSettingsAvailability: SubscriptionFeatureAvailability {
        status?.neuralModelSettings ?? .unavailable
    }

    func availability(of feature: PaidFeature) -> SubscriptionFeatureAvailability {
        status?.availability(of: feature) ?? .unavailable
    }

    var neuralModelSettings: NeuralModelSettings {
        let neuralModelConfig = container.applicationConfig.ultrasound.neuralModel
        let ultrasoundModelRepository = container.ultrasoundModelRepository
        switch neuralModelSettingsAvailability {
        case .available:
            return NeuralModelSettings(
                selectedNeuralModelId: ultrasoundModelRepository.getSelectedModelId(),
                isMarkdown: ultrasoundModelRepository.getIsMarkdown(),
                temperature: ultrasoundModelRepository.getTemperature() ?? neuralModelConfig.temperature,
                maxTokens: ultrasoundModelRepository.getMaxTokens() ?? neuralModelConfig.maxTokens
            )
        case .offered, .unavailable:
            return NeuralModelSettings(
                selectedNeuralModelId: ultrasoundModelRepository.getSelectedModelId(),
                isMarkdown: false,
                temperature: neuralModelConfig.temperature,
                maxTokens: neuralModelConfig.maxTokens
            )
        }
    }

    func refreshStatus() async {
        handle {
            try await self.container.subscriptionRepository.fetchStatus(
                configEntitlements: self.container.applicationConfig.entitlements
            )
        } onMainSuccess: { status in
            self.status = status
        }
    }

    func incrementRequestCount() {
        handle {
            try await self.container.subscriptionRepository.incrementRequestCount(
                configEntitlements: self.container.applicationConfig.entitlements
            )
        } onMainSuccess: { status in
            self.status = status
        }
    }

    func update(status: SubscriptionStatus?) {
        self.status = status
    }
}
