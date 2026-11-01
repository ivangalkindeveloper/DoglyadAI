import DoglyadUI
import SwiftUI

struct PaywallErrorView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: PaywallViewModel

    let errorDescription: String

    var body: some View {
        DText(
            errorDescription,
        ).dStyle(
            font: typography.textSmall,
            color: color.dangerDefault,
        )
        DButton(
            title: l10n[
                .paywallRetryButton,
            ],
            action: viewModel.onTapRetry,
        ).dStyle(
            .textWeak,
        )
    }
}
