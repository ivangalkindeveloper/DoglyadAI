import DoglyadUI
import Router
import SwiftUI

struct PatientConsentBottomSheet: View {
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: PatientConsentArguments

    init(
        arguments: PatientConsentArguments,
    ) {
        self.arguments = arguments
    }

    var body: some View {
        PatientConsentBottomSheetView(
            viewModel: PatientConsentViewModel(
                messager: messager,
                container: container,
                router: router,
                arguments: arguments,
                onSaved: { [ultrasoundViewModel] isNeedPatientConsent in
                    try await ultrasoundViewModel.saveIsNeedPatientConsent(
                        isNeedPatientConsent,
                    )
                },
                getSubscriptionStatus: { [subscriptionViewModel] in
                    subscriptionViewModel.status
                },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in
                    subscriptionViewModel.observeStatus(
                        observer,
                    )
                },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in
                    subscriptionViewModel.update(
                        status: status,
                    )
                },
                getSettingsAI: { [subscriptionViewModel] in
                    subscriptionViewModel.resolveSettingsAI()
                },
                onRefreshSubscriptionStatus: { [subscriptionViewModel] in
                    await subscriptionViewModel.refreshStatus()
                },
            ),
        )
    }
}
