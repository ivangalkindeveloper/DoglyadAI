import RevenueCatUI
import SwiftUI

struct SubscriptionCustomerCenterSheetView: View {
    @StateObject var viewModel: SubscriptionCustomerCenterViewModel

    var body: some View {
        CustomerCenterView()
            .onAppear(perform: viewModel.onAppear)
            .onCustomerCenterRestoreStarted {
                viewModel.onRestoreStarted()
            }
            .onCustomerCenterRestoreCompleted { _ in
                viewModel.onRestoreCompleted()
            }
    }
}
