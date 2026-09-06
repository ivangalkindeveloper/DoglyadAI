import DoglyadUI
import SwiftUI

struct StorageClearAllBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: StorageClearAllViewModel

    var body: some View {
        DBottomSheet(
            title: .storageClearAllWarningTitle,
            fraction: 0.3
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DText(.storageClearAllWarningDescription)
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold,
                        alignment: .center
                    )
                    .padding(.top, toolbarHeight + size.s24)
                    .padding(.horizontal, size.s16)
                Spacer()
            }
        } bottom: {
            DButton(
                title: .buttonClearAll,
                action: viewModel.onTapConfirm
            )
            .dStyle(.primaryButton)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
