import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import UIKit

@MainActor
final class SubscriptionRecoveryViewModel: DModuleViewModel<any SubscriptionRecoveryStateProtocol> {
    private let messager: DMessager
    @Published var focus: SubscriptionRecoveryFocus?
    @NestedObservableObject var recoveryTextController = DTextFieldController()
    private let createRecoveryKey: () async throws -> String
    private let recover: (String) async throws -> SubscriptionStatus?
    private var isDismissalRequested = false

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        arguments _: SubscriptionRecoveryArguments?,
        createRecoveryKey: @escaping () async throws -> String,
        recover: @escaping (String) async throws -> SubscriptionStatus?,
    ) {
        self.messager = messager
        self.createRecoveryKey = createRecoveryKey
        self.recover = recover
        super.init(
            state: SubscriptionRecoveryInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .subscriptionRecovery,
            ),
        )
    }

    var isProcessing: Bool {
        switch state {
        case _ as SubscriptionRecoveryLoadingState: true
        default: false
        }
    }

    var isRestoreEnabled: Bool {
        !isProcessing && !isDismissalRequested && !recoveryTextController.text.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ).isEmpty
    }

    private var stableState: any SubscriptionRecoveryStateProtocol {
        switch state {
        case let loading as SubscriptionRecoveryLoadingState: loading.previousState
        case let failed as SubscriptionRecoveryErrorState: failed.previousState
        default: state
        }
    }

    override func onDisappear() {
        super.onDisappear()
        switch state {
        case let loading as SubscriptionRecoveryLoadingState:
            emit(
                loading.previousState,
            )
        default: break
        }
    }

    func onTapBack() {
        guard !router.path.isEmpty else {
            return
        }
        isDismissalRequested = true
        cancelOperationTask()
        coordinator.pop()
    }

    func onFocusChanged(
        _ focus: SubscriptionRecoveryFocus?,
    ) {
        self.focus = focus
    }

    func unfocus() {
        focus = nil
    }

    func onTapCreateKey() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        unfocus()
        let previous = stableState
        let loading = SubscriptionRecoveryKeyCreationLoadingState(
            previousState: previous,
        )
        emit(
            loading,
        )
        operationTask = Task {
            guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                return
            }
            do {
                let key = try await createRecoveryKey()
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                emit(
                    SubscriptionRecoverySuccessState(
                        key: key,
                    ),
                )
            } catch {
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                emit(
                    SubscriptionRecoveryErrorState(
                        previousState: previous,
                        errorDescription: l10n.text(
                            .errorUnknownDescription,
                        ),
                    ),
                )
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
        }
    }

    func onTapCopyKey() {
        switch stableState {
        case let key as SubscriptionRecoverySuccessState: UIPasteboard.general.string = key.key
        default: break
        }
    }

    func onTapRestore() {
        guard isRestoreEnabled else {
            return
        }
        unfocus()
        let key = recoveryTextController.text.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        let previous = stableState
        let loading = SubscriptionRecoveryRestoreLoadingState(
            previousState: previous,
        )
        emit(
            loading,
        )
        operationTask = Task {
            guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                return
            }
            do {
                let status = try await recover(
                    key,
                )
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                updateSubscriptionStatus(
                    status,
                )
                isDismissalRequested = true
                coordinator.pop()
            } catch {
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                emit(
                    SubscriptionRecoveryErrorState(
                        previousState: previous,
                        errorDescription: l10n.text(
                            .subscriptionRecoveryFailedDescription,
                        ),
                    ),
                )
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
        }
    }
}
