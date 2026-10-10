import Router
import SwiftUI

struct WebDocumentBottomSheet: View {
    @EnvironmentObject private var l10n: L10N
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
                arguments: arguments,
            ),
        )
    }
}

#Preview {
    let l10n = DependencyContainer.previewable.l10n
    WebDocumentBottomSheet(
        arguments: WebDocumentBottomSheetArguments(
            url: URL(
                string: "https://ivangalkindeveloper.github.io/DoglyadAI/legal/privacy-policy/",
            )!,
            title: l10n[
                .privacyPolicyTitle,
            ],
        ),
    )
    .previewable()
}
