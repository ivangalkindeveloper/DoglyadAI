import DoglyadUI
import SwiftUI

struct PaywallLoadingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    init() {}

    var body: some View {
        HStack(
            spacing: size.s8,
        ) {
            DShimmerTextLines(
                lineHeight: size.s20,
                lineWidths: [0.65],
            )

            DShimmerTextLines(
                lineHeight: size.s20,
                lineWidths: [0.78],
            )
        }
        .padding(
            size.s12,
        )
        .background(
            DCardBackground(
                cornerRadius: size.s64,
                color: color.grayscaleInput,
            ),
        )

        VStack(
            alignment: .leading,
            spacing: size.s10,
        ) {
            ForEach(
                0 ..< 4,
                id: \.self,
            ) { index in
                HStack(
                    alignment: .top,
                    spacing: size.s8,
                ) {
                    DShimmerPlaceholder(
                        cornerRadius: .infinity,
                    )
                    .frame(
                        width: size.s20,
                        height: size.s20,
                    )

                    DShimmerTextLines(
                        lineHeight: size.s18,
                        lineWidths: [index.isMultiple(
                            of: 2,
                        ) ? 0.88 : 0.66],
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )

        VStack(
            spacing: size.s8,
        ) {
            ForEach(
                0 ..< 4,
                id: \.self,
            ) { index in
                HStack(
                    spacing: size.s8,
                ) {
                    DShimmerPlaceholder(
                        cornerRadius: .infinity,
                    )
                    .frame(
                        width: size.s32,
                        height: size.s32,
                    )

                    VStack(
                        alignment: .leading,
                        spacing: size.s2,
                    ) {
                        DShimmerTextLines(
                            lineHeight: size.s18,
                            lineWidths: [index.isMultiple(
                                of: 2,
                            ) ? 0.45 : 0.62],
                        )

                        DShimmerTextLines(
                            lineHeight: size.s16,
                            lineWidths: [0.3],
                        )
                    }
                }
                .padding(
                    size.s8,
                )
                .background(
                    DCardBackground(
                        cornerRadius: size.s64,
                        color: color.grayscaleBackground,
                    ),
                )
            }
        }
        .padding(
            .bottom,
            size.s8,
        )

        PaywallFooterLoadingView()
    }
}
