import DoglyadUI
import SwiftUI

struct PaywallContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s16,
        ) {
            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                DText(
                    l10n[
                        .paywallTitle,
                    ],
                )
                .dStyle(
                    font: typography.displaySmallBold,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )

                DText(
                    l10n[
                        .paywallDescription,
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
            }

            PaywallStateView(
                state: viewModel.state,
            )

            PaywallFooterLinksView()

            DText(
                l10n[
                    .paywallCancelDescription,
                ],
            )
            .dStyle(
                font: typography.textXSmall,
                color: color.grayscalePlacehold,
                alignment: .center,
            )
            .frame(
                maxWidth: .infinity,
            )
        }
    }
}
