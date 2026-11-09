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
            DListButton(
                icon: .send,
                title: viewModel.userEmailButtonTitle,
                action: viewModel.onTapUserEmail,
                isLoading: isProcessing,
                accessibilityIdentifier: "share.workEmail",
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
