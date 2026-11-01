import DoglyadUI
import SwiftUI

struct ManageSubscriptionSummaryCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionActiveState

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s16,
        ) {
            HStack {
                DText(
                    l10n[
                        .manageSubscriptionCurrentLabel,
                    ],
                ).dStyle(
                    font: typography.linkXSmall,
                    color: color.grayscaleLabel,
                )
                Spacer(
                    minLength: size.s8,
                )
                DText(
                    l10n[
                        .manageSubscriptionActiveLabel,
                    ],
                ).dStyle(
                    font: typography.linkXSmall,
                    color: color.successDefaultStrong,
                )
                .padding(
                    .horizontal,
                    size.s12,
                ).padding(
                    .vertical,
                    size.s4,
                )
                .background(
                    DCardBackground(
                        cornerRadius: size.s24,
                        color: color.successBackground,
                    ),
                )
            }
            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                DText(
                    state.tier.title,
                ).dStyle(
                    font: typography.displayLargeBold,
                    color: color.primaryDefault,
                )
                if let title = state.planTitle { DText(
                    title,
                ).dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleLabel,
                ) }
                if let expiration = viewModel.expirationDescription(
                    state.status,
                ) {
                    DText(
                        expiration,
                    ).dStyle(
                        font: typography.textSmall,
                    )
                }
            }
            VStack(
                alignment: .leading,
                spacing: size.s8,
            ) {
                ForEach(
                    state.tier.features.indices,
                    id: \.self,
                ) { index in
                    HStack(
                        alignment: .top,
                        spacing: size.s8,
                    ) {
                        DIcon(
                            .check,
                            color: color.primaryDefault,
                        ).accessibilityHidden(
                            true,
                        )
                        DText(
                            state.tier.features[
                                index,
                            ],
                        ).dStyle(
                            font: typography.textSmall,
                        ).fixedSize(
                            horizontal: false,
                            vertical: true,
                        )
                    }
                }
            }
            HStack(
                alignment: .top,
                spacing: size.s8,
            ) {
                DIcon(
                    .refresh,
                    color: color.grayscaleLabel,
                ).accessibilityHidden(
                    true,
                )
                DText(
                    state.status.isAutoRenewing ? l10n[
                        .manageSubscriptionAutoRenewOnDescription,
                    ] : l10n[
                        .manageSubscriptionAutoRenewOffDescription,
                    ],
                )
                .dStyle(
                    font: typography.textXSmall,
                    color: color.grayscaleLabel,
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading,
        )
        .padding(
            size.s20,
        )
        .background(
            DCardBackground(
                cornerRadius: size.s24,
                color: color.grayscaleBackground,
                borderColor: color.primaryDefault.opacity(
                    0.15,
                ),
                lineWidth: size.s1,
            ),
        )
    }
}
