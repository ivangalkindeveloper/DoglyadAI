import DoglyadUI
import SwiftUI

struct PaywallFooterLoadingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    init() {}

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s12,
        ) {
            DShimmerTextLines(
                lineHeight: size.s16,
                lineWidths: [0.94, 0.86, 0.98, 0.78, 0.56],
            )
            .padding(
                .horizontal,
                size.s8,
            )

            DShimmerTextLines(
                lineHeight: size.s18,
                lineWidths: [0.48],
            )
            .padding(
                .horizontal,
                size.s8,
            )
            .padding(
                .vertical,
                size.s12,
            )
        }
    }
}
