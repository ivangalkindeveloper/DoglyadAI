import DoglyadUI
import SwiftUI

struct ShareEmailButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ShareViewModel
    let isProcessing: Bool

    var body: some View {
        switch viewModel.subscriptionAvailability(
            of: .sendingReportByEmail,
        ) {
        case .available, .offered:
            DButtonCard(
                action: viewModel.onTapEmail,
            ) {
                ActionRowView(
                    icon: .mail,
                    title: l10n[
                        .buttonShareEmail,
                    ],
                )
            }.disabled(
                isProcessing,
            ).paidBadge(
                viewModel.subscriptionAvailability(
                    of: .sendingReportByEmail,
                ),
            ).transition(
                .opacity,
            )
        case .unavailable: EmptyView()
        }
    }
}
