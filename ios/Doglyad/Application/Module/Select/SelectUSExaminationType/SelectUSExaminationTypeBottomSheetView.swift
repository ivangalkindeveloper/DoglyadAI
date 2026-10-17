import DoglyadUI
import Foundation
import SwiftUI

struct SelectUSExaminationTypeBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SelectUSExaminationTypeViewModel

    var body: some View {
        let isSelecting = switch viewModel.state {
        case _ as SelectUSExaminationTypeSelectingState: true
        default: false
        }

        DBottomSheet(
            title: l10n[
                .usExaminationTypeTitle,
            ],
            fraction: 0.8,
        ) { toolbarHeight, bottomHeight in
            ScrollView(
                showsIndicators: false,
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: .zero,
                    pinnedViews: [.sectionHeaders],
                ) {
                    switch viewModel.state {
                    case _ as SelectUSExaminationTypeFailedState:
                        LoadingErrorView(
                            onRetry: viewModel.onTapRetry,
                        )
                    default: EmptyView()
                    }
                    ForEach(
                        viewModel.sections,
                    ) { section in
                        Section {
                            ForEach(
                                section.items,
                            ) { item in
                                DListButtonCard(
                                    title: item.type.localizedTitle,
                                    action: {
                                        viewModel.onTypeTap(
                                            item.type,
                                        )
                                    },
                                    isSelected: viewModel.isSelected(
                                        item.type,
                                    ),
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
                }
                .disabled(
                    isSelecting,
                )
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
                toolbarHeight,
                for: .scrollContent,
            )
        }
        bottom: {
            DText(
                l10n[
                    .usExaminationTypeAddingDescription,
                ],
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center,
            )
            .padding(
                .top,
                size.s16,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
