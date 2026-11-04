import DoglyadUI
import SwiftUI

struct ReportReceivedLoadingView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    var body: some View {
        DText(
            l10n[
                .reportReceivedGeneratingLabel,
            ],
        )
        .dStyle(
            font: typography.textMedium,
            color: color.grayscaleBackgroundWeak,
        )
        .dShimmer(
            cornerRadius: 0,
            masksContent: true,
        )
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
    }
}
