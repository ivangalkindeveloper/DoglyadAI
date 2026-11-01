import DoglyadUI
import SwiftUI

struct SubscriptionRecoveryStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionRecoveryViewModel
    let state: any SubscriptionRecoveryStateProtocol

    var body: some View {
        switch state {
        case let key as SubscriptionRecoveryKeyState:
            VStack(
                alignment: .leading,
                spacing: size.s12,
            ) {
                DText(
                    key.key,
                ).dStyle(
                    font: typography.textSmall,
                ).textSelection(
                    .enabled,
                ).privacySensitive()
                DButtonCard(
                    isPlain: true,
                    action: viewModel.onTapCopyKey,
                ) {
                    DText(
                        l10n[
                            .subscriptionRecoveryCopyButton,
                        ],
                    ).dStyle(
                        font: typography.linkSmall,
                        color: color.primaryDefault,
                    )
                    .frame(
                        minHeight: size.s48,
                    )
                }
            }.frame(
                maxWidth: .infinity,
                alignment: .leading,
            ).padding(
                size.s16,
            )
            .background(
                DCardBackground(
                    cornerRadius: size.s16,
                    color: color.grayscaleBackground,
                ),
            )
        case let loading as SubscriptionRecoveryLoadingState:
            SubscriptionRecoveryStateView(
                state: loading.previousState,
            )
            DShimmerPlaceholder().frame(
                height: size.s8,
            )
        case let failed as SubscriptionRecoveryFailedState:
            SubscriptionRecoveryStateView(
                state: failed.previousState,
            )
            DText(
                failed.errorDescription,
            ).dStyle(
                font: typography.textSmall,
                color: color.dangerDefault,
            )
        case _ as SubscriptionRecoveryDefaultState: EmptyView()
        default: EmptyView()
        }
    }
}
