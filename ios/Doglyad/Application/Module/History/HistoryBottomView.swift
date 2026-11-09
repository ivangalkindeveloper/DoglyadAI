import DoglyadUI
import SwiftUI

struct HistoryBottomView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        let (title, action): (L10NKey?, () -> Void) = switch viewModel.state {
        case _ as HistoryErrorState: (viewModel.sections.isEmpty ? .buttonUpdate : nil, viewModel.onTapRetry)
        case _ as HistoryEmptyState: (.buttonBack, viewModel.onTapBack)
        default: (nil, viewModel.onTapBack)
        }
        if let title {
            DButton(
                title: l10n[
                    title,
                ],
                action: action,
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
                ).combined(
                    with: .opacity,
                ),
            )
        }
    }
}
