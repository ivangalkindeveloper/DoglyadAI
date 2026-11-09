import DoglyadUI
import SwiftUI

struct TemplateListLoadingCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    var body: some View {
        DCard(
            action: {},
        ) {
            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                DShimmerTextLines(
                    lineHeight: size.s18,
                    lineWidths: [0.62],
                )

                DShimmerTextLines(
                    lineHeight: size.s18,
                    lineWidths: [0.78],
                )

                DShimmerTextLines(
                    lineHeight: size.s16,
                    lineWidths: [0.92, 0.76, 0.85, 0.56],
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading,
            )
        }
        .allowsHitTesting(
            false,
        )
    }
}
