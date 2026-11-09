import Combine
import DoglyadUI
import Router

@MainActor
final class PatientConsentViewModel: DModuleViewModel<any PatientConsentStateProtocol> {
    private let messager: DMessager
    private let arguments: PatientConsentArguments
    private let onSaved: (Bool) async throws -> Void
    private var isDismissalRequested = false

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        arguments: PatientConsentArguments,
        onSaved: @escaping (Bool) async throws -> Void,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
    ) {
        self.messager = messager
        self.arguments = arguments
        self.onSaved = onSaved
        super.init(
            state: PatientConsentInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .patientConsent,
            ),
        )
    }

    override func onDisappear() {
        super.onDisappear()
        isDismissalRequested = true
    }

    func onDoNotAskAgainChanged(
        _ isDoNotAskAgain: Bool,
    ) {
        guard !isDismissalRequested else {
            return
        }
        analytics.buttonTapped(
            .patientConsentPreference,
        )
        emit(
            PatientConsentInitialState(
                isDoNotAskAgain: isDoNotAskAgain,
            ),
        )
    }

    func onTapConfirm() {
        guard !isDismissalRequested else {
            return
        }
        analytics.buttonTapped(
            .patientConsentConfirm,
        )
        let isDoNotAskAgain = state.isDoNotAskAgain
        performLocalOperation {
            try await self.onSaved(
                !isDoNotAskAgain,
            )
        } onSuccess: { _ in
            guard self.state.isDoNotAskAgain == isDoNotAskAgain else {
                return
            }
            self.isDismissalRequested = true
            self.coordinator.dismissSheet()
            self.arguments.onConfirm()
        } onFailure: { _ in
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }
}
