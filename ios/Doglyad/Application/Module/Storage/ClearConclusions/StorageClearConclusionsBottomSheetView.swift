import DoglyadUI
import SwiftUI

struct StorageClearConclusionsBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageClearConclusionsViewModel

    var body: some View {
        DBottomSheet(
            title: .storageClearConclusionsWarningTitle,
            fraction: 0.3
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DText(.storageClearConclusionsWarningDescription)
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
                title: .buttonClear,
                action: viewModel.onTapConfirm
            )
            .dStyle(.primaryButton)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
