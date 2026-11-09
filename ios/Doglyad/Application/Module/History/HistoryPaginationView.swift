import DoglyadUI
import SwiftUI

struct HistoryPaginationView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        switch viewModel.state {
        case _ as HistoryErrorState:
            ErrorPaginationView(
                description: l10n.text(
                    .errorUnknownDescription,
                ),
                onRetry: viewModel.onOffsetAppear,
            )
        default:
            if viewModel.nextOffset != nil {
                Color.clear.frame(
                    height: 1,
                ).onAppear {
                    viewModel.onOffsetAppear()
                }
            }
        }
    }
}
