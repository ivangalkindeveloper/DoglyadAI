import DoglyadUI
import Foundation
import SwiftUI

struct SelectUSExaminationTypeBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: SelectUSExaminationTypeViewModel

    var body: some View {
        DBottomSheet(
            title: .usExaminationTypeTitle,
            fraction: 0.8
        ) { toolbarHeight, bottomHeight in
            ScrollView(
                showsIndicators: false
            ) {
                LazyVStack(
                    alignment: .leading,
                    spacing: .zero,
                    pinnedViews: [.sectionHeaders]
                ) {
                    ForEach(viewModel.sections) { section in
                        Section {
                            ForEach(section.items) { item in
                                DListButtonCard(
                                    title: item.type.getLocalizedTitle(for: Locale.current),
                                    action: {
                                        viewModel.onTypeTap(item.type)
                                    },
                                    isSelected: viewModel.isSelected(item.type)
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
                }
                .padding(.top, size.s16)
                .padding(.horizontal, size.s16)
                .padding(.bottom, bottomHeight + size.s16)
            }
            .contentMargins(.top, toolbarHeight, for: .scrollContent)
        }
        bottom: {
            DText(
                .usExaminationTypeAddingDescription
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center
            )
            .padding(.top, size.s16)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
