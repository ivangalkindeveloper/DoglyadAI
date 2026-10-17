import DoglyadUI
import SwiftUI

struct HistoryEmptyView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    var body: some View {
        VStack(
            spacing: .zero,
        ) {
            DImage(
                .doglyadMagnifier,
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
                l10n[
                    .historyEmptyDescription,
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
