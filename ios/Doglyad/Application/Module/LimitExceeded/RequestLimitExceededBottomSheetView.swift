import DoglyadUI
import SwiftUI

struct RequestLimitExceededBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: RequestLimitViewModel

    var body: some View {
        DBottomSheet(
            title: l10n[
                .requestLimitExceededTitle,
            ],
            isCloseButtonVisible: false,
            fraction: 0.3,
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero,
            ) {
                DText(
                    l10n[
                        .requestLimitExceededDescription,
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
            VStack(
                spacing: size.s8,
            ) {
                DButton(
                    title: l10n[
                        .settingsSubscriptionManageTitle,
                    ],
                    action: viewModel.onTapUpgrade,
                )
                .dStyle(
                    .primaryButton,
                )
                DButton(
                    title: l10n[
                        .buttonBack,
                    ],
                    action: viewModel.onTapBack,
                )
                .dStyle(
                    .card,
                )
            }
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
