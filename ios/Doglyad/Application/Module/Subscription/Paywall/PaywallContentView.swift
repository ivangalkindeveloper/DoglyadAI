import DoglyadUI
import SwiftUI

struct PaywallContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel

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
                .padding(
                    .bottom,
                    size.s8,
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
                .padding(
                    .bottom,
                    size.s8,
                )
            }

            PaywallStateView(
                state: viewModel.state,
            )
        }
    }
}
