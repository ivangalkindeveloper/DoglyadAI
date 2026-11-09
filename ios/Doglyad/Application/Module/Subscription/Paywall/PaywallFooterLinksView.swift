import DoglyadUI
import SwiftUI

struct PaywallFooterLinksView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel

    var body: some View {
        HStack(
            alignment: .top,
            spacing: size.s8,
        ) {
            PaywallFooterLinkButton(
                title: l10n[
                    .paywallRestoreButton,
                ],
                action: viewModel.onTapRestore,
                isDisabled:
                viewModel.isProcessing,
            )

            PaywallFooterLinkButton(
                title: l10n[
                    .buttonTermsAndConditions,
                ],
                action: viewModel.onTapTerms,
            )

            PaywallFooterLinkButton(
                title: l10n[
                    .buttonPrivacyPolicy,
                ],
                action: viewModel.onTapPrivacyPolicy,
            )
        }
    }
}
