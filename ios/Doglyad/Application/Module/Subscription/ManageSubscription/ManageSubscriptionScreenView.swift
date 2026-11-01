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
            DScrollVStack(
                spacing: size.s8,
                padding: EdgeInsets(
                    top: toolbarInset + size.s16,
                    leading: size.s16,
                    bottom: bottomInset + size.s32,
                    trailing: size.s16,
                ),
            ) {
                ManageSubscriptionStateView(
                    state: viewModel.state,
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
        ) { _ in
            viewModel.onRefresh()
        }
    }
}
