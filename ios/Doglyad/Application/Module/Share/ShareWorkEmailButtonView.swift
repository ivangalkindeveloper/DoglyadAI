import DoglyadUI
import SwiftUI

struct ShareWorkEmailButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ShareViewModel
    let isProcessing: Bool

    var body: some View {
        switch (viewModel.userEmail, viewModel.subscriptionAvailability(
            of: .sendingReportByEmail,
        )) {
        case (.some, .available), (.some, .offered):
            DButtonCard(
                action: viewModel.onTapUserEmail,
            ) {
                HStack(
                    spacing: size.s8,
                ) {
                    ShareSendingIconView()

                    DText(
                        viewModel.userEmailButtonTitle,
                    )
                    .dStyle(
                        font: typography.linkSmall,
                    )
                    .lineLimit(
                        1,
                    )
                    .truncationMode(
                        .middle,
                    )

                    Spacer()
                }
            }
            .disabled(
                isProcessing,
            )
            .accessibilityIdentifier(
                "share.workEmail",
            )
            .paidBadge(
                viewModel.subscriptionAvailability(
                    of: .sendingReportByEmail,
                ),
            )
            .transition(
                .opacity,
            )
        default: EmptyView()
        }
    }
}
