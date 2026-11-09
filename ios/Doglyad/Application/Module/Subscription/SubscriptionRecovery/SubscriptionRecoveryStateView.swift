import DoglyadUI
import SwiftUI

struct SubscriptionRecoveryStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionRecoveryViewModel
    let state: any SubscriptionRecoveryStateProtocol

    var body: some View {
        switch state {
        case let key as SubscriptionRecoverySuccessState:
            VStack(
                alignment: .leading,
                spacing: size.s12,
            ) {
                DText(
                    key.key,
                    accessibilityIdentifier: "subscriptionRecovery.generatedKey",
                ).dStyle(
                    font: typography.textSmall,
                ).textSelection(
                    .enabled,
                ).privacySensitive()

                DTextButton(
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
                    cornerRadius: size.cardCornerRadius,
                    color: color.grayscaleBackground,
                ),
            )

        case let loading as SubscriptionRecoveryLoadingState:
            SubscriptionRecoveryStateView(
                state: loading.previousState,
            )

        case let failed as SubscriptionRecoveryErrorState:
            SubscriptionRecoveryStateView(
                state: failed.previousState,
            )

        case _ as SubscriptionRecoveryInitialState: EmptyView()

        default: EmptyView()
        }
    }
}
