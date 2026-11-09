import DoglyadUI
import SwiftUI

struct WebDocumentBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: WebDocumentViewModel

    var body: some View {
        switch viewModel.state {
        case _ as WebDocumentErrorState:
            DButton(
                title: l10n[
                    .buttonRetry,
                ],
                action: viewModel.onTapRetry,
                accessibilityIdentifier: "webDocument.retry",
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                size.s16,
            )
        default: EmptyView()
        }
    }
}
