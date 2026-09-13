import DoglyadUI
import Router
import SwiftUI

struct ScanSpeechBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var messager: DMessager
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel
    let arguments: ScanSpeechBottomSheetArguments

    var body: some View {
        ScanSpeechBottomSheetView(
            viewModel: ScanSpeechViewModel(
                container: container,
                messager: messager,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    ScanSpeechBottomSheet(
        arguments: ScanSpeechBottomSheetArguments(
            onComplete: nil
        )
    )
    .previewable()
}
