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
                VStack(
                    spacing: .zero
                ) {
                    ForEach(viewModel.types) { type in
                        DListButtonCard(
                            title: type.getLocalizedTitle(for: Locale.current),
                            action: {
                                viewModel.onTypeTap(type)
                            },
                            isSelected: viewModel.isSelected(type)
                        )
                    }
                    .padding(.bottom, size.s8)
                }
                .padding(.top, toolbarHeight)
                .padding(size.s16)
                .padding(.bottom, bottomHeight)
            }
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
