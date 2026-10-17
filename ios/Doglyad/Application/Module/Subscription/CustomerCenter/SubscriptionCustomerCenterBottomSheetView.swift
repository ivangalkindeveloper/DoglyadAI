import DoglyadUI
import SwiftUI

struct SubscriptionCustomerCenterBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionCustomerCenterViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as SubscriptionCustomerCenterLoadingState: true
        default: false
        }

        DBottomSheet(
            title: l10n[
                .subscriptionSupportCenterTitle,
            ],
            fraction: 0.7,
        ) { topInset, _ in
            VStack(
                spacing: size.s16,
            ) {
                DText(
                    l10n[
                        .subscriptionSupportCenterDescription,
                    ],
                ).dStyle(
                    font: typography.textSmall,
                )
                switch viewModel.subscriptionStatus {
                case .some:
                    DButton(
                        title: l10n[
                            .subscriptionCustomerCenterManageButton,
                        ],
                        action: viewModel.onTapManageSubscription,
                    ).dStyle(
                        .primaryButton,
                    )
                case .none: EmptyView()
                }
                DButton(
                    title: l10n[
                        .subscriptionCustomerCenterRestoreButton,
                    ],
                    action: viewModel.onTapRestore,
                ).dStyle(
                    .textWeak,
                )
                switch viewModel.subscriptionStatus {
                case .some:
                    DButton(
                        title: l10n[
                            .subscriptionCustomerCenterRefundButton,
                        ],
                        action: viewModel.onTapRefund,
                    ).dStyle(
                        .textWeak,
                    )
                case .none: EmptyView()
                }
                DButton(
                    title: l10n[
                        .subscriptionCustomerCenterSupportButton,
                    ],
                    action: viewModel.onTapSupport,
                ).dStyle(
                    .textWeak,
                )
                switch viewModel.state {
                case _ as SubscriptionCustomerCenterLoadingState: DShimmerPlaceholder().frame(
                        height: size.s8,
                    )
                default: EmptyView()
                }
                switch viewModel.state {
                case let state as SubscriptionCustomerCenterFailedState:
                    DText(
                        state.errorDescription,
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.dangerDefault,
                    )
                default: EmptyView()
                }
                Spacer()
            }
            .disabled(
                isProcessing,
            )
            .padding(
                size.s16,
            )
            .padding(
                .top,
                topInset,
            )
        } bottom: {
            DButton(
                title: l10n[
                    .buttonBack,
                ],
                action: viewModel.onTapClose,
            ).dStyle(
                .textWeak,
            )
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
