import DoglyadUI
import SwiftUI

struct EmptyTemplatesBodyView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let description: LocalizedStringResource

    init(
        description: LocalizedStringResource,
    ) {
        self.description = description
    }

    var body: some View {
        VStack(
            spacing: size.s24,
        ) {
            DAssetScaleImage(
                .doglyadFile,
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
