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
        ) { toolbarInset, bottomInset in
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    alignment: .leading,
                    spacing: size.s24,
                ) {
                    ManageSubscriptionStateView(
                        state: viewModel.state,
                    )
                }
                .padding(
                    .horizontal,
                    size.s16,
                )
                .padding(
                    .top,
                    toolbarInset + size.s16,
                )
                .padding(
                    .bottom,
                    bottomInset + size.s32,
                )
            }
        }
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
        ) { _ in viewModel.onRefresh() }
    }
}
