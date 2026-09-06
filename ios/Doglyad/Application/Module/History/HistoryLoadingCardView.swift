import DoglyadUI
import SwiftUI

struct HistoryLoadingCardView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }

    var body: some View {
        HStack(spacing: .zero) {
            RoundedRectangle(cornerRadius: size.adaptiveCornerRadius / 4)
                .fill(color.grayscaleInput)
                .frame(
                    width: size.s64,
                    height: size.s64
                )
                .padding(.trailing, size.s20)

            VStack(
                alignment: .leading,
                spacing: size.s8
            ) {
                Capsule()
                    .fill(color.grayscaleInput)
                    .frame(
                        width: size.s128,
                        height: size.s14
                    )

                Capsule()
                    .fill(color.grayscaleInput)
                    .frame(
                        width: size.s96,
                        height: size.s14
                    )

                Capsule()
                    .fill(color.grayscaleInput)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: size.s14,
                        maxHeight: size.s14
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(size.s14)
        .background(color.grayscaleBackground)
        .cornerRadius(size.s16)
        .dShimmer(cornerRadius: size.s16)
    }
}
