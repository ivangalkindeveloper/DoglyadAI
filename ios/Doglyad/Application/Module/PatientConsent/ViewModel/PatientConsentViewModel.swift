import Combine
import DoglyadUI
import Router

@MainActor
final class PatientConsentViewModel: DModuleViewModel<any PatientConsentStateProtocol> {
    private let messager: DMessager
    private let arguments: PatientConsentArguments
    private let onSaved: (Bool) async throws -> Void

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

    func onDoNotAskAgainChanged(
        _ isDoNotAskAgain: Bool,
    ) {
        analytics.buttonTapped(
            .patientConsentPreference,
        )
        emit(
            state.copyWith(
                isDoNotAskAgain: isDoNotAskAgain,
            ),
        )
    }

    func onTapConfirm() {
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
            self.coordinator.dismissSheet()
            self.arguments.onConfirm()
        } onFailure: { _ in
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }
}
