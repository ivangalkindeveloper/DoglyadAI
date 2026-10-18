import DoglyadUI
import SwiftUI

struct ErrorInitializationView<Description: View>: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let title: LocalizedStringResource
    let description: () -> Description

    var body: some View {
        VStack(
            alignment: .center,
            spacing: .zero,
        ) {
            Spacer()

            DImage(
                .doglyadQuestion,
            )
            .scaledToFit()
            .frame(
                maxWidth: .infinity,
                alignment: .center,
            )
            .padding(
                size.s16,
            )

            DText(
                title,
            )
            .dStyle(
                font: typography.linkMedium,
                alignment: .center,
            )
            .padding(
                .bottom,
                size.s16,
            )

            description()
                .frame(
                    maxWidth: .infinity,
                )
                .padding(
                    .horizontal,
                    size.s14,
                )
                .padding(
                    .bottom,
                    size.s16,
                )

            Spacer()
        }
        .padding(
            size.s16,
        )
    }
}
