import DoglyadUI
import SwiftUI

struct SubscriptionCustomerCenterBottomSheetView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionCustomerCenterViewModel

    var body: some View {
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
                if viewModel.isSubscriptionActive {
                    DButton(
                        title: l10n[
                            .subscriptionCustomerCenterManageButton,
                        ],
                        action: viewModel.onTapManageSubscription,
                    ).dStyle(
                        .primaryButton,
                    )
                }
                DButton(
                    title: l10n[
                        .subscriptionCustomerCenterRestoreButton,
                    ],
                    action: viewModel.onTapRestore,
                ).dStyle(
                    .textWeak,
                )
                if viewModel.isSubscriptionActive {
                    DButton(
                        title: l10n[
                            .subscriptionCustomerCenterRefundButton,
                        ],
                        action: viewModel.onTapRefund,
                    ).dStyle(
                        .textWeak,
                    )
                }
                DButton(
                    title: l10n[
                        .subscriptionCustomerCenterSupportButton,
                    ],
                    action: viewModel.onTapSupport,
                ).dStyle(
                    .textWeak,
                )
                if viewModel.isLoading { DShimmerPlaceholder().frame(
                    height: size.s8,
                ) }
                if let error = viewModel.errorDescription {
                    DText(
                        error,
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.dangerDefault,
                    )
                }
                Spacer()
            }
            .disabled(
                viewModel.isLoading,
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
