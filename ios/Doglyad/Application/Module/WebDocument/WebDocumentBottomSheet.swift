import Router
import SwiftUI

struct WebDocumentBottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let arguments: WebDocumentBottomSheetArguments

    var body: some View {
        WebDocumentBottomSheetView(
            viewModel: WebDocumentViewModel(
                container: container,
                router: router,
                subscription: subscriptionViewModel,
                arguments: arguments
            )
        )
    }
}

#Preview {
    WebDocumentBottomSheet(
        arguments: WebDocumentBottomSheetArguments(
            url: URL(string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy/")!,
            title: .privacyPolicyTitle
        )
    )
    .previewable()
}
