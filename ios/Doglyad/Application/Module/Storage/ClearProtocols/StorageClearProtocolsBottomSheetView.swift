import DoglyadUI
import SwiftUI

struct StorageClearProtocolsBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageClearProtocolsViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .storageClearProtocolsWarningTitle,
            ],
            fraction: 0.3,
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero,
            ) {
                DText(
                    l10n[
                        .storageClearProtocolsWarningDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                    alignment: .center,
                )
                .padding(
                    .top,
                    toolbarHeight + size.s24,
                )
                .padding(
                    .horizontal,
                    size.s16,
                )
                Spacer()
            }
        } bottom: {
            DButton(
                title: l10n[
                    .buttonClear,
                ],
                action: viewModel.onTapConfirm,
            )
            .dStyle(
                .primaryButton,
            )
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
