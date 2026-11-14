import DoglyadUI
import SwiftUI

struct NeuralModelCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    let modelTitle: String
    let availableRequestCount: Int
    let onTap: () -> Void
    var isDisabled: Bool = false

    init(
        modelTitle: String,
        availableRequestCount: Int,
        onTap: @escaping () -> Void,
        isDisabled: Bool = false,
    ) {
        self.modelTitle = modelTitle
        self.availableRequestCount = availableRequestCount
        self.onTap = onTap
        self.isDisabled = isDisabled
    }

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

            DCard(
                action: onTap,
                content: {
                    VStack(
                        alignment: .leading,
                        spacing: size.s4,
                    ) {
                        NeuralModelValueRowView(
                            title: l10n[
                                .settingsAICardModelLabel,
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
                },
                isDisabled: isDisabled,
            )
        }
    }
}
