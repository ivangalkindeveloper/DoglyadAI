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
            subscription: subscription
        )
    }

    func onTapBack() {
        coordinator.pop()
    }

    func onTapClearConclusions() {
        coordinator.sheet(
            .storageClearConclusions,
            arguments: StorageClearConclusionsArguments(
                onConfirm: { [weak self] in
                    guard let self = self else { return }

                    handle {
                        await self.container.ultrasoundConclusionRepository.clearAllConclusions()
                    } onMainSuccess: { _ in
                        self.messager.show(
                            type: .success,
                            title: .storageClearConclusionsSuccessMessageTitle,
                            description: .storageClearConclusionsSuccessMessageDescription
                        )
                        self.coordinator.pop()
                    }
                }
            )
        )
    }

    func onTapClearAll() {
        coordinator.sheet(
            .storageClearAll,
            arguments: StorageClearAllArguments(
                onConfirm: { [weak self] in
                    guard let self = self else { return }

                    handle {
                        await self.container.ultrasoundConclusionRepository.clearAll()
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
