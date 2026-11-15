import DoglyadUI
import SwiftUI

struct ErrorBodyView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let description: String

    init(
        description: String,
    ) {
        self.description = description
    }

    var body: some View {
        VStack(
            spacing: size.s24,
        ) {
            DAssetScaleImage(
                .doglyadQuestion,
                widthScale: .regular,
            )

            DText(
                description,
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center,
            )
            .fixedSize(
                horizontal: false,
                vertical: true,
            )
        }
        .frame(
            maxWidth: .infinity,
        )
    }
}
