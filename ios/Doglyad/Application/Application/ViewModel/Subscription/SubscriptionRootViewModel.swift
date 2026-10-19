import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class SubscriptionRootViewModel: DStateViewModel<any SubscriptionRootStateProtocol> {
    private let container: DependencyContainer
    private let getStoredSettingsAI: () -> SettingsAI

    init(
        container: DependencyContainer,
        getStoredSettingsAI: (() -> SettingsAI)? = nil,
    ) {
        self.container = container
        self.getStoredSettingsAI = getStoredSettingsAI ?? { container.initialSettingsAI }
        let state: any SubscriptionRootStateProtocol = switch container.initialSubscriptionStatus {
        case let .some(
            status,
        ): SubscriptionRootActiveState(
                status: status,
            )
        case .none: SubscriptionRootInactiveState()
        }
        super.init(
            state: state,
        )
    }

    var status: SubscriptionStatus? {
        switch state {
        case let state as SubscriptionRootActiveState: state.status
        case _ as SubscriptionRootInactiveState: nil
        default: preconditionFailure(
                "Unexpected subscription root state",
            )
        }
    }

    func observeStatus(
        _ observer: @escaping (SubscriptionStatus?) -> Void,
    ) -> AnyCancellable {
        $state.map { state -> SubscriptionStatus? in
            switch state {
            case let state as SubscriptionRootActiveState: state.status
            case _ as SubscriptionRootInactiveState: nil
            default: preconditionFailure(
                    "Unexpected subscription root state",
                )
            }
        }.sink(
            receiveValue: observer,
        )
    }

    func resolveSettingsAI() -> SettingsAI {
        let neuralModelConfig = container.applicationConfig.ultrasound.neuralModel
        let settings = getStoredSettingsAI()
        if status?.isReportGenerationSettingsAvailable == true {
            return SettingsAI(
                transcriberType: settings.transcriberType,
                transcriptParserType: settings.transcriptParserType,
                selectedNeuralModelId: settings.selectedNeuralModelId,
                isMarkdown: settings.isMarkdown,
                temperature: settings.temperature ?? neuralModelConfig.temperature,
                maxTokens: settings.maxTokens ?? neuralModelConfig.maxTokens,
            )
        }
        return SettingsAI(
            transcriberType: settings.transcriberType,
            transcriptParserType: settings.transcriptParserType,
            selectedNeuralModelId: settings.selectedNeuralModelId,
            isMarkdown: false,
            temperature: neuralModelConfig.temperature,
            maxTokens: neuralModelConfig.maxTokens,
        )
    }

    func refreshStatus() async {
        handle {
            try await self.container.subscriptionRepository.fetchStatus(
                configEntitlements: self.container.applicationConfig.entitlements,
            )
        } onMainSuccess: { status in
            self.update(
                status: status,
            )
        }
    }

    func incrementRequestCount() {
        handle {
            try await self.container.subscriptionRepository.incrementRequestCount(
                configEntitlements: self.container.applicationConfig.entitlements,
            )
        } onMainSuccess: { status in
            self.update(
                status: status,
            )
        }
    }

    func update(
        status: SubscriptionStatus?,
    ) {
        switch status {
        case let .some(
            status,
        ): emit(
                SubscriptionRootActiveState(
                    status: status,
                ),
            )
        case .none: emit(
                SubscriptionRootInactiveState(),
            )
        }
    }
}
