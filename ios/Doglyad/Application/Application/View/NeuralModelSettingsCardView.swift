import DoglyadUI
import SwiftUI

struct NeuralModelSettingsCardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    let settings: NeuralModelSettings
    let availability: SubscriptionFeatureAvailability
    let onTap: () -> Void

    @ViewBuilder
    var body: some View {
        switch availability {
        case .unavailable:
            EmptyView()
        case .offered, .available:
            VStack(
                alignment: .leading,
                spacing: .zero,
            ) {
                DText(
                    l10n[
                        .neuralModelSettingsCardTitleLabel,
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
                        NeuralModelSettingsMarkdownRowView(
                            isMarkdown: .constant(
                                settings.isMarkdown,
                            ),
                        )

                        NeuralModelValueRowView(
                            title: l10n[
                                .neuralModelSettingsCardTemperatureLabel,
                            ],
                            value: String(
                                format: "%.2f",
                                settings.temperature ?? 0,
                            ),
                        )

                        NeuralModelValueRowView(
                            title: l10n[
                                .neuralModelSettingsCardMaxTokensLabel,
                            ],
                            value: "\(settings.maxTokens ?? 0)",
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading,
                    )
                }
                .paidBadge(
                    availability,
                )
            }
            .padding(
                .bottom,
                size.s16,
            )
        }
    }
}

private struct NeuralModelSettingsMarkdownRowView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    private static let switchNativeHeight: CGFloat = 31
    private static let switchNativeWidth: CGFloat = 51

    @EnvironmentObject var theme: DTheme

    @Binding var isMarkdown: Bool

    private var switchScale: CGFloat {
        size.s12 / Self.switchNativeHeight
    }

    var body: some View {
        HStack(
            alignment: .center,
            spacing: size.s8,
        ) {
            DText(
                l10n[
                    .neuralModelSettingsCardMarkdownLabel,
                ],
            )
            .dStyle(
                font: typography.textXSmall,
                color: color.grayscalePlacehold,
            )

            DToggle(
                "",
                isOn: $isMarkdown,
            )
            .labelsHidden()
            .toggleStyle(
                .switch,
            )
            .scaleEffect(
                switchScale,
            )
            .frame(
                width: Self.switchNativeWidth * switchScale,
                height: size.s12,
            )
            .allowsHitTesting(
                false,
            )
        }
    }
}
