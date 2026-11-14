import DoglyadUI
import SwiftUI

struct HistoryScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: HistoryViewModel

    init(
        viewModel: @autoclosure @escaping () -> HistoryViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .historyTitle,
            ],
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, bottomHeight in
                ZStack {
                    switch (viewModel.state, viewModel.sections.isEmpty) {
                    case (_ as HistoryInitialState, true): EmptyView()
                    case (_ as HistoryEmptyState, true):
                        DScrollVStack(
                            padding: EdgeInsets(
                                top: size.s16,
                                leading: size.s16,
                                bottom: size.s16,
                                trailing: size.s16,
                            ),
                        ) {
                            HistoryEmptyView()
                        }
                    case (_, false):
                        HistoryListView()
                    case (_ as HistoryErrorState, true):
                        ErrorBodyView(
                            description: l10n.text(
                                .errorUnknownDescription,
                            ),
                        )
                        .padding(
                            size.s16,
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                )
                .accessibilityIdentifier(
                    "history.loadedCount.\(viewModel.sections.reduce(0) { $0 + $1.reports.count })",
                )
                .padding(
                    .top,
                    toolbarInset,
                )
                .padding(
                    .bottom,
                    bottomHeight,
                )
            },
            bottom: {
                HistoryBottomView()
            },
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
