import DoglyadUI
import SwiftUI

struct SubscriptionPaywallContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionPaywallViewModel

    init() {}

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                DText(
                    l10n[
                        .subscriptionPaywallTitle,
                    ],
                )
                .dStyle(
                    font: typography.displaySmallBold,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .padding(
                    .bottom,
                    size.s8,
                )

                DText(
                    l10n[
                        .subscriptionPaywallDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .padding(
                    .bottom,
                    size.s8,
                )
            }

            SubscriptionPaywallStateView(
                state: viewModel.state,
            )
        }
    }
}
