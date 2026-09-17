import DoglyadUI
import SwiftUI

struct TemplateListLoadingCardView: DView {
    @EnvironmentObject var theme: DTheme

    var body: some View {
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

            VStack(
                alignment: .leading,
                spacing: size.s4
            ) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    Capsule()
                        .fill(color.grayscaleInput)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: size.s12,
                            maxHeight: size.s12
                        )
                }
            }
        }
        .padding(size.s14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.grayscaleBackground)
        .cornerRadius(size.adaptiveCardCornerRadius)
        .dShimmer(cornerRadius: size.adaptiveCardCornerRadius)
    }
}
