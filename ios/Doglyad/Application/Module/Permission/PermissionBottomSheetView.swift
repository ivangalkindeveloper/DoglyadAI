import DoglyadUI
import Foundation
import SwiftUI

struct PermissionBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: PermissionViewModel

    var body: some View {
        DBottomSheet(
            title: viewModel.title,
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero,
            ) {
                DText(
                    viewModel.description,
                )
                .dStyle(
                    font: typography.textSmall,
                    alignment: .center,
                )
                .padding(
                    .bottom,
                    size.s32,
                )
                DButton(
                    title: l10n[
                        .buttonOpenSettings,
                    ],
                    action: viewModel.onTapOpenSettings,
                )
                .dStyle(
                    .primaryButton,
                )
            }
            .padding(
                size.s16,
            )
            .padding(
                .top,
                toolbarHeight,
            )
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
