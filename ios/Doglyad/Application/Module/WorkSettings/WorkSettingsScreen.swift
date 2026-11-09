import DoglyadUI
import Router
import SwiftUI

struct WorkSettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: WorkSettingsArguments?

    var body: some View {
        WorkSettingsScreenView(
            viewModel: WorkSettingsViewModel(
                container: container,
                messager: messager,
                router: router,
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
                getInitialEmail: { [ultrasoundViewModel] in
                    ultrasoundViewModel.userEmail
                },
                getInitialIsNeedPatientConsent: { [ultrasoundViewModel] in
                    ultrasoundViewModel.isNeedPatientConsent
                },
                getInitialIsRecommendationsIncluded: { [ultrasoundViewModel] in
                    ultrasoundViewModel.isRecommendationsIncluded
                },
                getInitialIsPhotoRemarks: { [ultrasoundViewModel] in
                    ultrasoundViewModel.isPhotoRemarks
                },
                getInitialIsDescriptionRemarks: { [ultrasoundViewModel] in
                    ultrasoundViewModel.isDescriptionRemarks
                },
                onSaved: { [ultrasoundViewModel] email, isNeedPatientConsent, isRecommendationsIncluded, isPhotoRemarks, isDescriptionRemarks in
                    try await ultrasoundViewModel.saveUserSettings(
                        userEmail: email,
                        isNeedPatientConsent: isNeedPatientConsent,
                        isRecommendationsIncluded: isRecommendationsIncluded,
                        isPhotoRemarks: isPhotoRemarks,
                        isDescriptionRemarks: isDescriptionRemarks,
                    )
                },
            ),
        )
    }
}
