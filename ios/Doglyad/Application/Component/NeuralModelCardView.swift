import DoglyadUI
import SwiftUI

struct NeuralModelCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    let modelTitle: String
    let availableRequestCount: Int
    let onTap: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            DText(
                l10n[
                    .neuralModelCardTitleLabel,
                ],
            )
            .dStyle(
                font: typography.textSmall,
                color: color.grayscalePlacehold,
            )
            .padding(
                .horizontal,
                size.s8,
            )
            .padding(
                .bottom,
                size.s8,
            )

            DButtonCard(
                action: onTap,
            ) {
                VStack(
                    alignment: .leading,
                    spacing: size.s4,
                ) {
                    NeuralModelValueRowView(
                        title: l10n[
                            .neuralModelSettingsCardModelLabel,
                        ],
                        value: modelTitle,
                    )

                    NeuralModelValueRowView(
                        title: l10n[
                            .neuralModelCardAvailableRequestsLabel,
                        ],
                        value: "\(availableRequestCount)",
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
            }
        }
    }
}
