import DoglyadUI
import Router
import SwiftUI

struct UserSettingsScreen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: UserSettingsScreenArguments?

    var body: some View {
        UserSettingsScreenView(
            viewModel: UserSettingsViewModel(
                container: container,
                messager: messager,
                router: router,
                subscription: subscriptionViewModel,
                initialEmail: ultrasoundViewModel.userEmail,
                onEmailSaved: { [ultrasoundViewModel] email in
                    ultrasoundViewModel.saveUserEmail(userEmail: email)
                }
            )
        )
    }
}

#Preview {
    UserSettingsScreen(
        arguments: nil
    )
    .previewable()
}
