import DoglyadUI
import SwiftUI

struct ReportReceivedEmailButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ReportReceivedViewModel
    let isSending: Bool

    var body: some View {
        switch (viewModel.userEmail, viewModel.subscriptionAvailability(
            of: .sendingReportByEmail,
        )) {
        case (.some, .available), (.some, .offered):
            DButton(
                image: .send,
                title: viewModel.userEmailButtonTitle,
                truncatingTitleSuffix: viewModel.userEmail,
                badge: viewModel.userEmailButtonBadge,
                action: viewModel.onTapUserEmail,
                isLoading: isSending,
            )
            .dStyle(
                .textWeak,
            )
            .transition(
                .opacity,
            )
        default: EmptyView()
        }
    }
}
