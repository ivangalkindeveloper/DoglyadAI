import Combine
import DoglyadSpeech
import Foundation
import Router
import UIKit

@MainActor
final class SelectTranscriberViewModel: DModuleViewModel<any SelectTranscriberStateProtocol> {
    @Published private(set) var options: [TranscriberType] = [.whisperKit]
    let currentValue: TranscriberType
    private let arguments: SelectTranscriberArguments
    private let getAvailableAppleEngine: @MainActor (Locale) async -> DSpeechEngine?
    private var availabilityObservation: AnyCancellable?

    init(
        container: DependencyContainer,
        router: DRouter,
        arguments: SelectTranscriberArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        getAvailableAppleEngine: @escaping @MainActor (Locale) async -> DSpeechEngine? = { locale in
            await DSpeechFactory.availableAppleEngine(
                locale: locale,
            )
        },
    ) {
        self.arguments = arguments
        self.getAvailableAppleEngine = getAvailableAppleEngine
        currentValue = arguments.currentValue
        super.init(
            state: SelectTranscriberState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .selectTranscriber,
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

    func onSelect(
        _ type: TranscriberType,
    ) {
        guard options.contains(
            type,
        ) else { return }
        analytics.buttonTapped(
            .selectTranscriber,
        )
        arguments.onSelected(
            type,
        )
        coordinator.dismissSheet()
    }

    private func refreshAvailability() {
        handle {
            await self.getAvailableAppleEngine(
                self.container.language.currentLocale,
            )
        } onMainSuccess: { engine in
            self.options = engine.map { [TranscriberType(
                engine: $0,
            ), .whisperKit] } ?? [.whisperKit]
        }
    }
}
