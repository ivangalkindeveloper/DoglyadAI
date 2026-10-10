import DoglyadUI
import SwiftUI

struct NeuralModelSettingsCardView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var ultrasoundViewModel: UltrasoundViewModel
    @EnvironmentObject private var subscription: SubscriptionViewModel

    let feature: PaidFeature
    let onTap: () -> Void

    @ViewBuilder
    var body: some View {
        switch subscription.availability(
            of: feature,
        ) {
        case .unavailable:
            EmptyView()
        case .offered, .available:
            VStack(
                alignment: .leading,
                spacing: .zero,
            ) {
                DText(
                    l10n[
                        .scanNeuralModelSettingsTitleLabel,
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
                            isMarkdown: $ultrasoundViewModel.isMarkdown,
                        )

                        NeuralModelValueRowView(
                            title: l10n[
                                .scanNeuralModelSettingsTemperatureLabel,
                            ],
                            value: String(
                                format: "%.2f",
                                ultrasoundViewModel.temperature,
                            ),
                        )

                        NeuralModelValueRowView(
                            title: l10n[
                                .scanNeuralModelSettingsMaxTokensLabel,
                            ],
                            value: "\(ultrasoundViewModel.maxTokens)",
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading,
                    )
                }
                .paidBadge(
                    feature,
                )
            }
            .padding(
                .bottom,
                size.s16,
            )
        }
    }
}

private struct NeuralModelSettingsMarkdownRowView: DView {
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
                    .scanNeuralModelSettingsMarkdownLabel,
                ],
            )
            .dStyle(
                font: typography.textXSmall,
                color: color.grayscalePlacehold,
            )

            Toggle(
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
