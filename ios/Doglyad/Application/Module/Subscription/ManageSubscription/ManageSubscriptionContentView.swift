import DoglyadUI
import SwiftUI

struct ManageSubscriptionContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: ManageSubscriptionContentState

    var body: some View {
        switch state {
        case let active as ManageSubscriptionActiveState: ManageSubscriptionSummaryCardView(
                state: active,
            )
        case let inactive as ManageSubscriptionInactiveState:
            VStack(
                alignment: .leading,
                spacing: size.s8,
            ) {
                DText(
                    l10n[
                        .manageSubscriptionEmptyTitle,
                    ],
                ).dStyle(
                    font: typography.displaySmallBold,
                )
                DText(
                    inactive.notice ?? l10n.text(
                        .manageSubscriptionEmptyDescription,
                    ),
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscalePlacehold,
                )
            }.frame(
                maxWidth: .infinity,
                alignment: .leading,
            ).padding(
                size.s24,
            )
            .background(
                DCardBackground(
                    cornerRadius: size.s24,
                    color: color.grayscaleBackground,
                ),
            )
        default: EmptyView()
        }
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            SectionHeaderView(
                title: l10n[
                    .manageSubscriptionActionsTitle,
                ],
            )
            DListButtonCard(
                image: .iconTemplates,
                title: l10n[
                    .manageSubscriptionChangeTypeButton,
                ],
                description: l10n[
                    .manageSubscriptionChangeTypeDescription,
                ],
                action: viewModel.onTapChangeType,
            )
            .accessibilityIdentifier(
                "manageSubscription.changeType",
            )
            DListButtonCard(
                image: .iconHistory,
                title: l10n[
                    .manageSubscriptionRestoreButton,
                ],
                description: l10n[
                    .manageSubscriptionRestoreDescription,
                ],
                action: viewModel.onTapRestore,
            )
            .accessibilityIdentifier(
                "manageSubscription.restore",
            )
            if viewModel.isManageAvailable {
                DListButtonCard(
                    image: .iconSettings,
                    title: viewModel.manageTitle,
                    description: viewModel.manageDescription,
                    action: viewModel.onTapManageSubscription,
                )
                .accessibilityIdentifier(
                    "manageSubscription.manage",
                )
            }
            switch state {
            case let active as ManageSubscriptionActiveState:
                switch active.status.source {
                case .yookassa:
                    if !active.status.isAutoRenewing {
                        DText(
                            l10n[
                                .manageSubscriptionRenewalStoppedDescription,
                            ],
                        )
                        .dStyle(
                            font: typography.textXSmall,
                            color: color.grayscalePlacehold,
                        )
                        .padding(
                            .horizontal,
                            size.s12,
                        ).padding(
                            .top,
                            size.s4,
                        )
                    }
                case .apple, .none: EmptyView()
                }
            default: EmptyView()
            }
        }.disabled(
            viewModel.isProcessing,
        )
        VStack(
            alignment: .leading,
            spacing: size.s8,
        ) {
            SectionHeaderView(
                title: l10n[
                    .manageSubscriptionAccessTitle,
                ],
            )
            DListButtonCard(
                image: .iconGuard,
                title: l10n[
                    .manageSubscriptionRecoveryButton,
                ],
                description: l10n[
                    .manageSubscriptionRecoveryDescription,
                ],
                action: viewModel.onTapRecovery,
            )
            .accessibilityIdentifier(
                "manageSubscription.recovery",
            )
            HStack(
                spacing: size.s16,
            ) {
                DButtonCard(
                    isPlain: true,
                    action: viewModel.onTapSupport,
                ) {
                    DText(
                        l10n[
                            .manageSubscriptionSupportButton,
                        ],
                    ).dStyle(
                        font: typography.linkXSmall,
                        color: color.primaryDefault,
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: size.s48,
                    )
                }
                switch state {
                case _ as ManageSubscriptionActiveState:
                    DButtonCard(
                        isPlain: true,
                        action: viewModel.onTapRefund,
                    ) {
                        DText(
                            l10n[
                                .manageSubscriptionRefundButton,
                            ],
                        ).dStyle(
                            font: typography.linkXSmall,
                            color: color.primaryDefault,
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: size.s48,
                        )
                    }
                default: EmptyView()
                }
            }
        }.disabled(
            viewModel.isProcessing,
        )
    }
}
