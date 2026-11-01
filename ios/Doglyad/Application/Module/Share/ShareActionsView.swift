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

            DButtonCard(
                action: viewModel.onTapCopy,
            ) {
                ActionRowView(
                    icon: .copy,
                    title: l10n[
                        .buttonCopy,
                    ],
                )
            }.disabled(
                isProcessing,
            )

            DShareLink(
                item: viewModel.shareMessage,
            ) {
                ActionRowView(
                    icon: .export,
                    title: l10n[
                        .buttonShare,
                    ],
                )
            }.buttonStyle(
                DButtonStyle(
                    .card,
                ),
            ).disabled(
                isProcessing,
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
