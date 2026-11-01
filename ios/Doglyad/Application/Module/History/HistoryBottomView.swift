import DoglyadUI
import SwiftUI

struct HistoryBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        switch viewModel.state {
        case _ as HistoryEmptyState:
            DButton(
                title: l10n[
                    .buttonBack,
                ],
                action: viewModel.onTapBack,
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                size.s16,
            )
            .transition(
                .move(
                    edge: .bottom,
                )
                .combined(
                    with: .opacity,
                ),
            )
        default: EmptyView()
        }
    }
}
