import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ReadyMadeTemplateListViewModel

    var body: some View {
        switch viewModel.state {
        case _ as ReadyMadeTemplateListErrorState:
            DButton(
                title: l10n[
                    .readyMadeTemplateListRetryButton,
                ],
                action: viewModel.onTapRetry,
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
