import DoglyadUI
import SwiftUI

struct HistoryListView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: HistoryViewModel

    var body: some View {
        ScrollView(
            showsIndicators: false,
        ) {
            LazyVStack(
                alignment: .leading,
                spacing: .zero,
                pinnedViews: [.sectionHeaders],
            ) {
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

                HistoryPaginationView()
            }
            .padding(
                .horizontal,
                size.s16,
            )
            .padding(
                .vertical,
                size.s16,
            )
        }
    }
}
