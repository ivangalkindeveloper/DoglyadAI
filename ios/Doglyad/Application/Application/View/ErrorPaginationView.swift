import DoglyadUI
import SwiftUI

struct ErrorPaginationView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    let description: String
    let onRetry: () -> Void

    init(
        description: String,
        onRetry: @escaping () -> Void,
    ) {
        self.description = description
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(
            spacing: size.s20,
        ) {
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

            DButton(
                title: l10n[
                    .buttonRetry,
                ],
                action: onRetry,
            )
            .dStyle(
                .primaryChip,
            )
        }
        .frame(
            maxWidth: .infinity,
        )
        .padding(
            .vertical,
            size.s16,
        )
    }
}
