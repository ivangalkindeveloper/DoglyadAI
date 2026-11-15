import Combine
import DoglyadSpeech
import Foundation
import Router
import UIKit

@MainActor
final class SelectTranscriberViewModel: DModuleViewModel<any SelectTranscriberStateProtocol> {
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
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        getAvailableAppleEngine: @escaping @MainActor (Locale) async -> DSpeechEngine? = { locale in
            await DSpeechFactory.availableAppleEngine(
                locale: locale,
            )
        },
    ) {
        var options: [TranscriberType] = [.whisperKit]
        if container.language.currentLocale.language.languageCode?.identifier == "ru" {
            options.append(
                .tOne,
            )
        }
        currentValue = arguments.currentValue
        self.arguments = arguments
        self.getAvailableAppleEngine = getAvailableAppleEngine
        super.init(
            state: SelectTranscriberInitialState(
                options: options,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .selectTranscriber,
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

    override func onDisappear() {
        super.onDisappear()
        availabilityObservation?.cancel()
        availabilityObservation = nil
    }

    func onSelect(
        _ type: TranscriberType,
    ) {
        guard state.options.contains(
            type,
        ) else {
            return
        }
        analytics.buttonTapped(
            .selectTranscriber,
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
        cancelOperationTask()
        operationTask = handle {
            await self.getAvailableAppleEngine(
                self.container.language.currentLocale,
            )
        } onMainSuccess: { engine in
            guard !Task.isCancelled else {
                return
            }
            var options = engine.map {
                [TranscriberType(
                    engine: $0,
                ), .whisperKit]
            } ?? [.whisperKit]
            if self.container.language.currentLocale.language.languageCode?.identifier == "ru" {
                options.append(
                    .tOne,
                )
            }
            self.emit(
                self.state.copyWith(
                    options: options,
                ),
            )
        }
    }
}
