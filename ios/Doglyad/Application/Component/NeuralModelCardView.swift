import DoglyadUI
import SwiftUI

struct NeuralModelCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscriptionViewModel: SubscriptionViewModel

    let onTap: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            DText(
                l10n[
                    .scanNeuralModelTitleLabel,
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
                            .scanNerualModelSettingsModelLabel,
                        ],
                        value: ultrasoundViewModel.neuralModel.title,
                    )

                    NeuralModelValueRowView(
                        title: l10n[
                            .scanNeuralModelSettingsAvailableRequestsLabel,
                        ],
                        value: "\(subscriptionViewModel.availableRequestCount)",
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
