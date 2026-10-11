import DoglyadUI
import Router
import SwiftUI

struct UserSettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionRootViewModel
    let arguments: UserSettingsArguments?

    var body: some View {
        UserSettingsScreenView(
            viewModel: UserSettingsViewModel(
                container: container,
                messager: messager,
                router: router,
                getSubscriptionStatus: { [subscriptionViewModel] in subscriptionViewModel.status },
                observeSubscriptionStatus: { [subscriptionViewModel] observer in subscriptionViewModel.observeStatus(
                    observer,
                ) },
                onSubscriptionStatusUpdated: { [subscriptionViewModel] status in subscriptionViewModel.update(
                    status: status,
                ) },
                getNeuralModelSettings: { [subscriptionViewModel] in subscriptionViewModel.neuralModelSettings },
                onRequestCountIncremented: { [subscriptionViewModel] in subscriptionViewModel.incrementRequestCount() },
                getInitialEmail: { [ultrasoundViewModel] in ultrasoundViewModel.userEmail },
                getInitialIncludeRecommendations: { [ultrasoundViewModel] in ultrasoundViewModel.includeRecommendations },
                getInitialIsPhotoRemarks: { [ultrasoundViewModel] in ultrasoundViewModel.isPhotoRemarks },
                getInitialIsDescriptionRemarks: { [ultrasoundViewModel] in ultrasoundViewModel.isDescriptionRemarks },
                onSaved: { [ultrasoundViewModel] email, includeRecommendations, isPhotoRemarks, isDescriptionRemarks in
                    ultrasoundViewModel.saveUserSettings(
                        userEmail: email,
                        includeRecommendations: includeRecommendations,
                        isPhotoRemarks: isPhotoRemarks,
                        isDescriptionRemarks: isDescriptionRemarks,
                    )
                },
            ),
        )
    }
}

#Preview {
    UserSettingsScreen(
        arguments: nil,
    )
    .previewable()
}
