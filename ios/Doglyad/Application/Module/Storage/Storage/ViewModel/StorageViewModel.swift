import Combine
import DoglyadNetwork
import DoglyadSpeech
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class StorageViewModel: DModuleViewModel<any StorageStateProtocol> {
    @Published private(set) var isSpeechModelAvailable = false
    private let messager: DMessager
    private var speechModelObservation: AnyCancellable?
    private let presentationPath: NavigationPath

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        self.messager = messager
        presentationPath = router.path
        super.init(
            state: StorageInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .storage,
            ),
        )
    }

    override func onInit() {
        speechModelObservation = DSpeechWhisperKitModel.shared.$state.sink { [weak self] _ in
            self?.isSpeechModelAvailable = DSpeechWhisperKitModel.shared.isDownloaded
        }
    }

    #if DEBUG
        func configurePreviewSpeechModel(
            isAvailable: Bool,
        ) {
            isSpeechModelAvailable = isAvailable
        }
    #endif

    func onTapBack() {
        cancelOperationTask()
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
                    guard let self, router.path == self.presentationPath else {
                        return
                    }
                    performLocalOperation {
                        try await self.container.ultrasoundReportRepository.clearAllReports()
                    } onSuccess: { _ in
                        self.emit(
                            StorageInitialState(),
                        )
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
                    } onFailure: { error in
                        self.emit(
                            StorageErrorState(
                                error: error,
                            ),
                        )
                        self.messager.showUnknownError(
                            l10n: self.l10n,
                        )
                    }
                },
            ),
        )
    }

    func onTapDeleteSpeechModel() {
        guard isSpeechModelAvailable, router.path == presentationPath else {
            return
        }
        analytics.buttonTapped(
            .storageDeleteSpeechModel,
        )
        coordinator.sheet(
            .storageClearSpeechModel,
            arguments: StorageClearSpeechModelArguments(
                onConfirm: { [weak self] in
                    self?.deleteSpeechModel()
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
                    guard let self, router.path == self.presentationPath else {
                        return
                    }
                    performLocalOperation {
                        try await self.container.ultrasoundReportRepository.clearAll()
                    } onSuccess: { _ in
                        self.emit(
                            StorageInitialState(),
                        )
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
                    } onFailure: { error in
                        self.emit(
                            StorageErrorState(
                                error: error,
                            ),
                        )
                        self.messager.showUnknownError(
                            l10n: self.l10n,
                        )
                    }
                },
            ),
        )
    }

    private func deleteSpeechModel() {
        guard isSpeechModelAvailable, router.path == presentationPath else {
            return
        }
        performLocalOperation {
            try await DSpeechWhisperKitModel.shared.deleteDownloadedModel()
        } onSuccess: { _ in
            self.emit(
                StorageInitialState(),
            )
            self.messager.show(
                type: .success,
                title: self.l10n[
                    .storageDeleteSpeechModelSuccessMessageTitle,
                ],
                description: self.l10n[
                    .storageDeleteSpeechModelSuccessMessageDescription,
                ],
            )
            self.coordinator.pop()
        } onFailure: { error in
            self.emit(
                StorageErrorState(
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }
}
