import DoglyadUI
import SwiftUI

struct PaywallFooterLinksView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: PaywallViewModel

    init() {}

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s12,
        ) {
            DText(
                viewModel.legalAttributedText(
                    theme: theme,
                    locale: l10n.locale,
                ),
            )
            .padding(
                .horizontal,
                size.s8,
            )
            .environment(
                \.openURL,
                OpenURLAction { url in
                    viewModel.onLegalAttributedEnvironment(
                        url: url,
                    )
                },
            )

            DButton(
                title: l10n[
                    .paywallRestoreButton,
                ],
                action: viewModel.onTapRestore,
                isDisabled: viewModel.isRestoreDisabled,
                accessibilityIdentifier: "paywall.restore",
            ).dStyle(
                .primaryText,
            )
        }
    }
}
