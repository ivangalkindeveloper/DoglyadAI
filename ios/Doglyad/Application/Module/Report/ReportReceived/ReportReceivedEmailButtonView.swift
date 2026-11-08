import DoglyadUI
import SwiftUI

struct ReportReceivedEmailButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ReportReceivedViewModel

    private var isSending: Bool {
        switch viewModel.state {
        case _ as ReportReceivedLoadingState: true
        default: false
        }
    }

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
