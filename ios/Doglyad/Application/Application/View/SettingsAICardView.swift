import DoglyadUI
import SwiftUI

struct SettingsAICardView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    let settings: SettingsAI
    let onTap: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero,
        ) {
            DText(
                l10n[
                    .settingsAICardTitleLabel,
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
                    SettingsAIMarkdownRowView(
                        isMarkdown: .constant(
                            settings.isMarkdown,
                        ),
                    )
                    NeuralModelValueRowView(
                        title: l10n[
                            .settingsAICardTemperatureLabel,
                        ],
                        value: String(
                            format: "%.2f",
                            settings.temperature ?? 0,
                        ),
                    )
                    NeuralModelValueRowView(
                        title: l10n[
                            .settingsAICardMaxTokensLabel,
                        ],
                        value: "\(settings.maxTokens ?? 0)",
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
            }
        }
        .padding(
            .bottom,
            size.s16,
        )
    }
}

private struct SettingsAIMarkdownRowView: DViewProtocol {
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
                    .settingsAICardMarkdownLabel,
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
