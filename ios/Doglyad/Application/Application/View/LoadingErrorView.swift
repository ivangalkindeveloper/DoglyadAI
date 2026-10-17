import DoglyadUI
import SwiftUI

struct LoadingErrorView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    let onRetry: () -> Void

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            DText(
                l10n[
                    .errorUnknownDescription,
                ],
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
                alignment: .center,
            )
            DButton(
                title: l10n[
                    .buttonUpdate,
                ],
                action: onRetry,
            )
            .dStyle(
                .textWeak,
            )
        }
        .padding(
            size.s16,
        )
    }
}
