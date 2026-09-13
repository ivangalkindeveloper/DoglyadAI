import DoglyadUI
import SwiftUI

struct SubscriptionScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SubscriptionScreenViewModel

    var body: some View {
        DScreen(
            title: .subscriptionTitle,
            onTapBack: viewModel.onTapBack
        ) { toolbarInset, _ in
            ScrollView(
                showsIndicators: false
            ) {
                VStack(
                    spacing: size.s8
                ) {
                    DListButtonCard(
                        title: .subscriptionChangeTypeTitle,
                        description: .subscriptionChangeTypeDescription,
                        action: viewModel.onTapChangeType
                    )
                    DListButtonCard(
                        title: .subscriptionSupportCenterTitle,
                        description: .subscriptionSupportCenterDescription,
                        action: viewModel.onTapSupportCenter
                    )
                }
                .padding(size.s16)
                .padding(.top, toolbarInset)
                .padding(.bottom, size.s32)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
