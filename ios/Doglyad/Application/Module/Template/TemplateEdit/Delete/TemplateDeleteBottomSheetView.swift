import DoglyadUI
import SwiftUI

struct TemplateDeleteBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: TemplateDeleteViewModel

    var body: some View {
        DBottomSheet(
            title: .templateDeleteTitle,
            fraction: 0.25
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DText(.templateDeleteDescription)
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
                title: .buttonDelete,
                action: viewModel.onTapConfirm
            )
            .dStyle(.primaryButton)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
