import DoglyadUI
import SwiftUI

struct ShareActionsView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ShareViewModel
    let toolbarHeight: CGFloat

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as ShareSendingState: true
        default: false
        }

        VStack(
            spacing: size.s8,
        ) {
            ShareWorkEmailButtonView(
                isProcessing: isProcessing,
            )

            ShareEmailButtonView(
                isProcessing: isProcessing,
            )

            DListButton(
                icon: .copy,
                title: l10n[
                    .buttonCopy,
                ],
                accessibilityIdentifier: "share.copy",
                action: viewModel.onTapCopy,
                isDisabled: isProcessing,
            )

            DListButton(
                icon: .export,
                title: l10n[
                    .buttonShare,
                ],
                shareItem: viewModel.shareMessage,
                isDisabled: isProcessing,
            )

            Spacer()
        }.padding(
            .top,
            toolbarHeight + size.s16,
        ).padding(
            .horizontal,
            size.s16,
        )
    }
}
