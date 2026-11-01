import DoglyadUI
import SwiftUI

struct HistoryPaginationView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        switch viewModel.state {
        case _ as HistoryFailedState:
            LoadingErrorView(
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
