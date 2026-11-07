import DoglyadUI
import SwiftUI

struct ImportMediaBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ImportMediaViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .importMediaTitle,
            ],
            fraction: 0.25,
        ) { toolbarHeight, _ in
            VStack(
                spacing: size.s8,
            ) {
                DListButton(
                    icon: .camera,
                    title: l10n[
                        .buttonCamera,
                    ],
                    action: viewModel.onTapCamera,
                )

                DListButton(
                    icon: .image,
                    title: l10n[
                        .buttonGallery,
                    ],
                    action: viewModel.onTapGallery,
                )

                Spacer()
            }
            .padding(
                .top,
                toolbarHeight + size.s16,
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
        .onDisappear(
            perform: viewModel.onDisappear,
        )
    }
}
