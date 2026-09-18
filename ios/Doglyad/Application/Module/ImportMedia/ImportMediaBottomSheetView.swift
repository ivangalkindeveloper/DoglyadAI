import DoglyadUI
import SwiftUI

struct ImportMediaBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ImportMediaViewModel

    var body: some View {
        DBottomSheet(
            title: .importMediaTitle,
            fraction: 0.25
        ) { toolbarHeight, _ in
            VStack(
                spacing: size.s8
            ) {
                DButtonCard(
                    action: viewModel.onTapCamera
                ) {
                    row(
                        icon: .camera,
                        title: .buttonCamera
                    )
                }

                DButtonCard(
                    action: viewModel.onTapGallery
                ) {
                    row(
                        icon: .image,
                        title: .buttonGallery
                    )
                }

                Spacer()
            }
            .padding(.top, toolbarHeight + size.s16)
            .padding(.horizontal, size.s16)
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
    }

    private func row(
        icon: ImageResource,
        title: LocalizedStringResource
    ) -> some View {
        HStack(
            spacing: size.s8
        ) {
            DIcon(
                icon,
                color: color.grayscaleHeader
            )
            DText(title)
                .dStyle(
                    font: typography.linkSmall
                )
            Spacer()
        }
    }
}
