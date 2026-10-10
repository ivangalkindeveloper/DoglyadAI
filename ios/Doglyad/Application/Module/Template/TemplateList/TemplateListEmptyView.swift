import DoglyadUI
import SwiftUI

struct TemplateListEmptyView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    var body: some View {
        VStack(
            spacing: .zero,
        ) {
            Image(
                .doglyadFile,
            )
            .resizable()
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
                l10n[
                    .templateListEmptyDescription,
                ],
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
