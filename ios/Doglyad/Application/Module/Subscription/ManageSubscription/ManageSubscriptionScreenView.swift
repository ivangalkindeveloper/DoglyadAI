import DoglyadUI
import SwiftUI
import UIKit

struct ManageSubscriptionScreenView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @StateObject var viewModel: ManageSubscriptionViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .manageSubscriptionTitle,
            ],
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, bottomInset in
                switch viewModel.state {
                case let failed as ManageSubscriptionErrorState where failed.previousState == nil:
                    ManageSubscriptionLoadingErrorView(
                        state: failed,
                    )
                    .padding(
                        size.s16,
                    )
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .padding(
                        .bottom,
                        bottomInset,
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                    )
                default:
                    ManageSubscriptionScrollableView(
                        state: viewModel.state,
                        toolbarInset: toolbarInset,
                        bottomInset: bottomInset,
                    )
                }
            },
            bottom: {
                ManageSubscriptionBottomView()
            },
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification,
            ),
        ) { _ in
            viewModel.onRefresh()
        }
    }
}
