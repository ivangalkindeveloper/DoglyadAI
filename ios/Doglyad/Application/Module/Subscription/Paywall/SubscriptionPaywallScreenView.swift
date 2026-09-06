import RevenueCatUI
import SwiftUI

struct SubscriptionPaywallScreenView: View {
    @EnvironmentObject private var router: DRouter
    @StateObject var viewModel: SubscriptionPaywallViewModel

    var body: some View {
        PaywallView(
            fonts: DPaywallFontProvider(),
            displayCloseButton: !router.path.isEmpty
        )
        .onAppear(perform: viewModel.onAppear)
        .onPurchaseStarted { package in
            viewModel.onPurchaseStarted(
                productId: package.storeProduct.productIdentifier
            )
        }
        .onPurchaseCompleted { _ in
            viewModel.onPurchaseCompleted()
        }
        .onRestoreStarted {
            viewModel.onRestoreStarted()
        }
        .onRestoreCompleted { _ in
            viewModel.onRestoreCompleted()
        }
        .onRequestedDismissal {
            viewModel.onRequestedDismissal()
        }
    }
}
