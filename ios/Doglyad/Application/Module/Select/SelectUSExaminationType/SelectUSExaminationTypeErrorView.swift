import DoglyadUI
import SwiftUI

struct SelectUSExaminationTypeErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: SelectUSExaminationTypeViewModel

    var body: some View {
        switch viewModel.state {
        case _ as SelectUSExaminationTypeFailedState:
            LoadingErrorView(
                onRetry: viewModel.onTapRetry,
            )
        default: EmptyView()
        }
    }
}
