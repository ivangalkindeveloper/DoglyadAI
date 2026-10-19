import Combine
import Foundation
import Router
import UIKit

@MainActor
final class SelectTranscriptParserViewModel: DModuleViewModel<any SelectTranscriptParserStateProtocol> {
    let options = TranscriptParserType.allCases
    let currentValue: TranscriptParserType
    private let arguments: SelectTranscriptParserArguments

    @Published private(set) var isFoundationModelsAvailable: Bool
    private var availabilityObservation: AnyCancellable?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: SelectTranscriptParserArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        self.arguments = arguments
        currentValue = arguments.currentValue
        isFoundationModelsAvailable = container.examinationNeuralModelFactory.isFoundationModelsAvailable
        super.init(
            state: SelectTranscriptParserState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .selectTranscriptParser,
            ),
        )
    }

    override func onInit() {
        availabilityObservation = NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification,
        ).sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshAvailability() }
        }
        refreshAvailability()
    }

    func isSelectionEnabled(
        for type: TranscriptParserType,
    ) -> Bool {
        switch type {
        case .foundationModels:
            isFoundationModelsAvailable
        case .server:
            true
        }
    }

    func onSelect(
        _ type: TranscriptParserType,
    ) {
        refreshAvailability()
        guard isSelectionEnabled(
            for: type,
        ) else { return }
        analytics.buttonTapped(
            .selectTranscriptParser,
        )
        arguments.onSelected(
            type,
        )
        coordinator.dismissSheet()
    }

    private func refreshAvailability() {
        isFoundationModelsAvailable = container.examinationNeuralModelFactory.isFoundationModelsAvailable
    }
}
