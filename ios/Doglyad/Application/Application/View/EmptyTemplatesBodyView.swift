import DoglyadUI
import SwiftUI

struct EmptyTemplatesBodyView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let description: LocalizedStringResource

    var body: some View {
        VStack(
            spacing: .zero,
        ) {
            DImage(
                .doglyadFile,
            )
            .scaledToFit()
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center,
            )
            .padding(
                .horizontal,
                size.s64,
            )

            DText(
                description,
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center,
            )
        }
        .padding(
            .top,
            size.screenHeight / 6,
        )
    }
}
