import DoglyadUI
import SwiftUI

struct StorageClearAllBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: StorageClearAllViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .storageClearAllWarningTitle,
            ],
            fraction: 0.3,
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero,
            ) {
                DText(
                    l10n[
                        .storageClearAllWarningDescription,
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
                    .buttonClearAll,
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
