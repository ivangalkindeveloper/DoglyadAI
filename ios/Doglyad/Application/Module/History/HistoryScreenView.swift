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
            content: { toolbarInset, bottomHeight in
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
                                    ForEach(section.reports) { report in
                                        HistoryCardView(
                                            report: report,
                                            onTap: {
                                                viewModel.onTapReport(value: report)
                                            }
                                        )
                                        .padding(.bottom, size.s4)
                                    }
                                } header: {
                                    SectionHeaderView(
                                        title: section.title
                                    )
                                } footer: {
                                    Color.clear
                                        .frame(height: size.s12)
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
                    .padding(.top, size.s16)
                    .padding(.horizontal, size.s16)
                    .padding(.bottom, bottomHeight + size.s16)
                }
                .contentMargins(.top, toolbarInset, for: .scrollContent)
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
        .onAppear(perform: viewModel.onAppear)
        .environmentObject(viewModel)
    }
}
