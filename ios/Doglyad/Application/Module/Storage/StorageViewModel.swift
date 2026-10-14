import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class StorageViewModel: DModuleViewModel {
    private let messager: DMessager

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        self.messager = messager
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .storage,
            ),
        )
    }

    func onTapBack() {
        analytics.buttonTapped(
            .storageBack,
        )
        coordinator.pop()
    }

    func onTapClearProtocols() {
        analytics.buttonTapped(
            .storageClearProtocols,
        )
        coordinator.sheet(
            .storageClearProtocols,
            arguments: StorageClearProtocolsArguments(
                onConfirm: { [weak self] in
                    guard let self else { return }

                    handle {
                        try await self.container.ultrasoundReportRepository.clearAllReports()
                    } onMainSuccess: { _ in
                        self.messager.show(
                            type: .success,
                            title: self.container.l10n[
                                .storageClearProtocolsSuccessMessageTitle,
                            ],
                            description: self.container.l10n[
                                .storageClearProtocolsSuccessMessageDescription,
                            ],
                        )
                        self.coordinator.pop()
                    }
                },
            ),
        )
    }

    func onTapClearAll() {
        analytics.buttonTapped(
            .storageClearAll,
        )
        coordinator.sheet(
            .storageClearAll,
            arguments: StorageClearAllArguments(
                onConfirm: { [weak self] in
                    guard let self else { return }

                    handle {
                        try await self.container.ultrasoundReportRepository.clearAll()
                    } onMainSuccess: { _ in
                        self.messager.show(
                            type: .success,
                            title: self.container.l10n[
                                .storageClearAllSuccessMessageTitle,
                            ],
                            description: self.container.l10n[
                                .storageClearAllSuccessMessageDescription,
                            ],
                        )
                        self.coordinator.resetToOnBoarding()
                    }
                },
            ),
        )
    }
}
