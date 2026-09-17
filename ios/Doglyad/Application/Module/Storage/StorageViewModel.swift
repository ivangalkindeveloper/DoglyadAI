import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class StorageViewModel: DViewModel {
    private let messager: DMessager

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        self.messager = messager
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.storage)
        )
    }

    func onTapBack() {
        analytics.buttonTapped(.storageBack)
        coordinator.pop()
    }

    func onTapClearProtocols() {
        analytics.buttonTapped(.storageClearProtocols)
        coordinator.sheet(
            .storageClearProtocols,
            arguments: StorageClearProtocolsArguments(
                onConfirm: { [weak self] in
                    guard let self = self else { return }

                    handle {
                        await self.container.ultrasoundReportRepository.clearAllReports()
                    } onMainSuccess: { _ in
                        self.messager.show(
                            type: .success,
                            title: .storageClearProtocolsSuccessMessageTitle,
                            description: .storageClearProtocolsSuccessMessageDescription
                        )
                        self.coordinator.pop()
                    }
                }
            )
        )
    }

    func onTapClearAll() {
        analytics.buttonTapped(.storageClearAll)
        coordinator.sheet(
            .storageClearAll,
            arguments: StorageClearAllArguments(
                onConfirm: { [weak self] in
                    guard let self = self else { return }

                    handle {
                        await self.container.ultrasoundReportRepository.clearAll()
                    } onMainSuccess: { _ in
                        self.messager.show(
                            type: .success,
                            title: .storageClearAllSuccessMessageTitle,
                            description: .storageClearAllSuccessMessageDescription
                        )
                        self.coordinator.resetToOnBoarding()
                    }
                }
            )
        )
    }
}
