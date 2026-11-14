import DoglyadUI
import SwiftUI

struct ReportReceivedLoadingView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    init() {}

    var body: some View {
        DText(
            l10n[
                .reportReceivedGeneratingLabel,
            ],
            accessibilityIdentifier: "reportReceived.generating",
        )
        .dStyle(
            font: typography.textSmall,
            color: color.grayscaleBackgroundWeak,
            alignment: .leading,
        )
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
        .dShimmer()
    }
}
