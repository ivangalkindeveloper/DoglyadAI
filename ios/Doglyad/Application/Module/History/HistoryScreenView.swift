import DoglyadUI
import SwiftUI

struct HistoryScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .historyTitle,
            ],
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, bottomHeight in
                ScrollView(
                    showsIndicators: false,
                ) {
                    LazyVStack(
                        alignment: .leading,
                        spacing: .zero,
                        pinnedViews: [.sectionHeaders],
                    ) {
                        switch (viewModel.state, viewModel.sections.isEmpty) {
                        case (_ as HistoryLoadingState, true):
                            HistoryLoadingView(
                                cardCount: viewModel.pageSize,
                            )
                            .transition(
                                .opacity,
                            )
                        case (_ as HistoryEmptyState, true):
                            HistoryEmptyView()
                                .transition(
                                    .opacity,
                                )
                        case (_, false):
                            ForEach(
                                viewModel.sections,
                            ) { section in
                                Section {
                                    ForEach(
                                        section.reports,
                                    ) { report in
                                        HistoryCardView(
                                            report: report,
                                            onTap: {
                                                viewModel.onTapReport(
                                                    value: report,
                                                )
                                            },
                                        )
                                        .padding(
                                            .bottom,
                                            size.s4,
                                        )
                                    }
                                } header: {
                                    SectionHeaderView(
                                        title: section.title,
                                    )
                                } footer: {
                                    Color.clear
                                        .frame(
                                            height: size.s12,
                                        )
                                }
                            }

                            switch viewModel.state {
                            case _ as HistoryFailedState:
                                LoadingErrorView(
                                    onRetry: viewModel.onOffsetAppear,
                                )
                            default:
                                switch viewModel.nextOffset {
                                case .some:
                                    HistoryOffsetLoadingView().transition(
                                        .opacity,
                                    ).onAppear { viewModel.onOffsetAppear() }
                                case .none: EmptyView()
                                }
                            }
                        case (_ as HistoryFailedState, true):
                            LoadingErrorView(
                                onRetry: viewModel.onTapRetry,
                            )
                        default:
                            EmptyView()
                        }
                    }
                    .padding(
                        .top,
                        size.s16,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                    .padding(
                        .bottom,
                        bottomHeight + size.s16,
                    )
                }
                .contentMargins(
                    .top,
                    toolbarInset,
                    for: .scrollContent,
                )
            },
            bottom: {
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
