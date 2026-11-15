import Combine
import Foundation
import Router
import UIKit

@MainActor
final class SelectTranscriptParserViewModel: DModuleViewModel<any SelectTranscriptParserStateProtocol> {
    let options = TranscriptParserType.allCases
    let currentValue: TranscriptParserType
    private let arguments: SelectTranscriptParserArguments
    private let getFoundationModelsAvailability: () -> Bool
    private var availabilityObservation: AnyCancellable?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: SelectTranscriptParserArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        getFoundationModelsAvailability: (() -> Bool)? = nil,
    ) {
        currentValue = arguments.currentValue
        self.arguments = arguments
        let availability = getFoundationModelsAvailability ?? {
            container.examinationNeuralModelFactory.isFoundationModelsAvailable
        }
        self.getFoundationModelsAvailability = availability
        super.init(
            state: SelectTranscriptParserDefaultState(
                isFoundationModelsAvailable: availability(),
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .selectTranscriptParser,
            ),
        )
    }

    override func onInit() {
        observeAvailability()
    }

    override func onReappear() {
        guard availabilityObservation == nil else {
            return
        }
        observeAvailability()
    }

    func isSelectionEnabled(
        for type: TranscriptParserType,
    ) -> Bool {
        switch type {
        case .foundationModels:
            state.isFoundationModelsAvailable
        case .server:
            true
        }
    }

    override func onDisappear() {
        super.onDisappear()
        availabilityObservation?.cancel()
        availabilityObservation = nil
    }

    func onSelect(
        _ type: TranscriptParserType,
    ) {
        refreshAvailability()
        guard isSelectionEnabled(
            for: type,
        ) else {
            return
        }
        analytics.buttonTapped(
            .selectTranscriptParser,
        )
        arguments.onSelected(
            type,
        )
        cancelOperationTask()
        availabilityObservation?.cancel()
        availabilityObservation = nil
        coordinator.dismissSheet()
    }

    private func observeAvailability() {
        availabilityObservation = NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification,
        ).sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, availabilityObservation != nil else {
                    return
                }
                refreshAvailability()
            }
        }
        refreshAvailability()
    }

    private func refreshAvailability() {
        emit(
            state.copyWith(
                isFoundationModelsAvailable: getFoundationModelsAvailability(),
            ),
        )
    }
}
