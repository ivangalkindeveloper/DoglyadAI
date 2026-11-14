import Combine
import DoglyadUI
import Foundation
import NestedObservableObject

@MainActor
final class SubscriptionRecoveryViewModel: DModuleViewModel<any SubscriptionRecoveryStateProtocol> {
    private let messager: DMessager
    @Published var focus: SubscriptionRecoveryFocus?
    @NestedObservableObject var recoveryTextController = DTextFieldController()
    private let arguments: SubscriptionRecoveryArguments?
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
        arguments: SubscriptionRecoveryArguments?,
        recover: @escaping (String) async throws -> SubscriptionStatus?,
    ) {
        self.messager = messager
        self.arguments = arguments
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
        case _ as SubscriptionRecoveryRestoreLoadingState: true
        default: false
        }
    }

    override func onDisappear() {
        super.onDisappear()
        emit(
            SubscriptionRecoveryInitialState(),
        )
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

    func onTapRestore() {
        guard !isProcessing, !isDismissalRequested else {
            return
        }
        unfocus()
        let key = recoveryTextController.text.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        let loading = SubscriptionRecoveryRestoreLoadingState()
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
                guard status != nil else {
                    emit(
                        SubscriptionRecoveryInitialState(),
                    )
                    messager.show(
                        type: .error,
                        title: l10n[
                            .subscriptionRecoveryNoActiveTitle,
                        ],
                        description: l10n[
                            .subscriptionRecoveryNoActiveDescription,
                        ],
                    )
                    return
                }
                isDismissalRequested = true
                messager.show(
                    type: .success,
                    title: l10n[
                        .subscriptionRecoverySuccessTitle,
                    ],
                    description: l10n[
                        .subscriptionRecoverySuccessDescription,
                    ],
                )
                coordinator.pop()
                arguments?.onRecovered?()
            } catch {
                guard !Task.isCancelled, !isDismissalRequested, state === loading else {
                    return
                }
                emit(
                    SubscriptionRecoveryInitialState(),
                )
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
        }
    }
}
