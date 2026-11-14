import DoglyadUI
import SwiftUI

struct ReadyMadeTemplateListLoadingCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

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
                DShimmerTextLines(
                    lineHeight: size.s18,
                    lineWidths: [0.62],
                )

                DShimmerTextLines(
                    lineHeight: size.s18,
                    lineWidths: [0.78],
                )
            }

            DShimmerTextLines(
                lineHeight: size.s20,
                lineWidths: [0.92, 0.76, 0.85, 0.58, 0.88, 0.66, 0.94, 0.52],
                spacing: 16 * 0.15,
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
        .padding(
            size.s16,
        )
        .background(
            color.grayscaleBackground,
        )
        .cornerRadius(
            size.cardCornerRadius,
        )
    }
}
