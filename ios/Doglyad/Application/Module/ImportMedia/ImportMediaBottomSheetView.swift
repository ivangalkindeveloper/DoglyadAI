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
                DButtonCard(
                    action: viewModel.onTapCamera,
                ) {
                    ActionRowView(
                        icon: .camera,
                        title: l10n[
                            .buttonCamera,
                        ],
                    )
                }

                DButtonCard(
                    action: viewModel.onTapGallery,
                ) {
                    ActionRowView(
                        icon: .image,
                        title: l10n[
                            .buttonGallery,
                        ],
                    )
                }

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
