import Router
import SwiftUI

struct SelectDateOfBirthBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: SelectDateOfBirthArguments?

    var body: some View {
        SelectDateOfBirthBottomSheetView(
            viewModel: SelectDateOfBirthViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    SelectDateOfBirthBottomSheet(
        arguments: nil
    )
    .previewable()
}
