import DoglyadUI
import SwiftUI

struct HistoryScreenView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        DScreen(
            title: .historyTitle,
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, _ in
                ScrollView(
                    showsIndicators: false
                ) {
                    LazyVStack(
                        alignment: .leading,
                        spacing: .zero,
                        pinnedViews: [.sectionHeaders]
                    ) {
                        if viewModel.isLoading {
                            HistoryLoadingView(
                                cardCount: viewModel.pageSize
                            )
                        } else if viewModel.sections.isEmpty {
                            HistoryEmptyView()
                        } else {
                            ForEach(viewModel.sections) { section in
                                Section {
                                    ForEach(section.conclusions) { conclusion in
                                        HistoryCard(
                                            conclusion: conclusion,
                                            action: {
                                                viewModel.onTapConclusion(value: conclusion)
                                            }
                                        )
                                        .padding(.bottom, size.s4)
                                    }
                                } header: {
                                    HistoryDayHeaderView(
                                        title: section.title
                                    )
                                }
                            }

                            if viewModel.hasMoreOffset {
                                HistoryOffsetLoadingView()
                                    .onAppear {
                                        viewModel.onOffsetAppear()
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, size.s16)
                    .padding(.top, size.s16)
                    .padding(.bottom, size.s64)
                }
                .padding(.top, toolbarInset)
            },
            bottom: {
                if viewModel.isEmpty {
                    DButton(
                        title: .buttonBack,
                        action: viewModel.onTapBack
                    )
                    .dStyle(.primaryButton)
                    .padding(size.s16)
                }
            }
        )
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
