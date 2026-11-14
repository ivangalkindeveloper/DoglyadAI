import DoglyadUI
import SwiftUI

struct SubscriptionManageSummaryCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: SubscriptionManageViewModel
    let state: SubscriptionManageActiveState

    init(
        state: SubscriptionManageActiveState,
    ) {
        self.state = state
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            HStack {
                DText(
                    state.tier.title,
                ).dStyle(
                    font: typography.displayMediumBold,
                    color: viewModel.summaryTextColor(
                        state.tier.id,
                        theme: theme,
                    ),
                ).dShimmer(
                    isShimmering: viewModel.summaryTitleShimmering(
                        state.tier.id,
                    ),
                    masksContent: true,
                )

                Spacer(
                    minLength: size.s8,
                )

                DText(
                    l10n[
                        .subscriptionManageActiveLabel,
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
                        color: color.successBackgroundStrong,
                    ),
                )
            }

            VStack(
                alignment: .leading,
                spacing: size.s4,
            ) {
                if let title = state.planTitle {
                    DText(
                        title,
                    ).dStyle(
                        font: typography.textSmall,
                        color: viewModel.summarySecondaryTextColor(
                            state.tier.id,
                            theme: theme,
                        ),
                    )
                }

                if let expiration = viewModel.expirationDescription(
                    state.status,
                ) {
                    DText(
                        expiration,
                    ).dStyle(
                        font: typography.textSmall,
                        color: viewModel.summaryTextColor(
                            state.tier.id,
                            theme: theme,
                        ),
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
                            color: viewModel.summaryFeatureIconColor(
                                state.tier.id,
                                theme: theme,
                            ),
                        )

                        DText(
                            state.tier.features[
                                index,
                            ],
                        ).dStyle(
                            font: typography.textSmall,
                            color: viewModel.summaryTextColor(
                                state.tier.id,
                                theme: theme,
                            ),
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
                    color: viewModel.summarySecondaryTextColor(
                        state.tier.id,
                        theme: theme,
                    ),
                )

                DText(
                    state.status.isAutoRenewing ? l10n[
                        .subscriptionManageAutoRenewOnDescription,
                    ] : l10n[
                        .subscriptionManageAutoRenewOffDescription,
                    ],
                )
                .dStyle(
                    font: typography.textXSmall,
                    color: viewModel.summarySecondaryTextColor(
                        state.tier.id,
                        theme: theme,
                    ),
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
        .background {
            DCardBackground(
                cornerRadius: size.s24,
                color: color.grayscaleBackground,
                gradient: viewModel.summaryBackgroundGradient(
                    state.tier.id,
                    theme: theme,
                ),
            )
        }
    }
}
