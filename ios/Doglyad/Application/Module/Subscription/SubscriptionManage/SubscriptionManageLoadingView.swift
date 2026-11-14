import DoglyadUI
import SwiftUI

struct SubscriptionManageLoadingView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    init() {}

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            HStack {
                DShimmerTextLines(
                    lineHeight: size.s32,
                    lineWidths: [0.5],
                )

                DShimmerPlaceholder(
                    cornerRadius: size.s24,
                )
                .frame(
                    width: size.s64 + size.s16,
                    height: size.s24,
                )
            }

            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                DShimmerTextLines(
                    lineHeight: size.s18,
                    lineWidths: [0.6, 0.8],
                )
            }

            VStack(
                alignment: .leading,
                spacing: size.s8,
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
                            ) ? 0.9 : 0.68],
                        )
                    }
                }
            }

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
                    lineHeight: size.s16,
                    lineWidths: [0.76],
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
        .padding(
            size.s20,
        )
        .background(
            DCardBackground(
                cornerRadius: size.s24,
                color: color.grayscaleBackground,
            ),
        )

        VStack(
            spacing: size.s8,
        ) {
            ForEach(
                0 ..< 5,
                id: \.self,
            ) { index in
                DCard(
                    action: {},
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: size.s4,
                    ) {
                        DShimmerTextLines(
                            lineHeight: size.s18,
                            lineWidths: [index.isMultiple(
                                of: 2,
                            ) ? 0.65 : 0.8],
                        )

                        DShimmerTextLines(
                            lineHeight: size.s16,
                            lineWidths: [0.9, 0.55],
                        )
                    }
                }
                .allowsHitTesting(
                    false,
                )
            }
        }
    }
}
