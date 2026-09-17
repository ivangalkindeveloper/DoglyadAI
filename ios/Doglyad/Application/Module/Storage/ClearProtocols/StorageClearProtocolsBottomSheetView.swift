import DoglyadUI
import SwiftUI

struct StorageClearProtocolsBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageClearProtocolsViewModel

    var body: some View {
        DBottomSheet(
            title: .storageClearProtocolsWarningTitle,
            fraction: 0.3
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DText(.storageClearProtocolsWarningDescription)
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
