import DoglyadUI
import SwiftUI

struct HistoryPaginationView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        switch viewModel.state {
        case _ as HistoryFailedState:
            ErrorPaginationView(
                description: l10n.text(
                    .errorUnknownDescription,
                ),
                onRetry: viewModel.onOffsetAppear,
            )
        default:
            if viewModel.nextOffset != nil {
                HistoryOffsetLoadingView().transition(
                    .opacity,
                ).onAppear {
                    viewModel.onOffsetAppear()
                }
            }
        }
    }
}
