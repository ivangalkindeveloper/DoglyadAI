import DoglyadUI
import SwiftUI

struct SubscriptionPaywallScreenView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionPaywallViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .subscriptionPaywallTitle,
            ],
            onTapBack: viewModel.closeAction,
        ) { topInset, _ in
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: size.s16,
                ) {
                    DText(
                        l10n[
                            .subscriptionPaywallDescription,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                    )
                    if viewModel.isLoading, viewModel.plans.isEmpty {
                        DShimmerPlaceholder().frame(
                            height: size.s64,
                        )
                        DShimmerPlaceholder().frame(
                            height: size.s64,
                        )
                    }
                    plans
                    errorContent
                    DButton(
                        title: l10n[
                            .subscriptionPaywallRestoreButton,
                        ],
                        action: viewModel.onTapRestore,
                        isLoading: viewModel.isLoading,
                    ).dStyle(
                        .textWeak,
                    )
                    DText(
                        l10n[
                            .subscriptionPaywallTermsDescription,
                        ],
                    ).dStyle(
                        font: typography.textXSmall,
                        color: color.grayscalePlacehold,
                    )
                    DButton(
                        title: l10n[
                            .buttonPrivacyPolicy,
                        ],
                        action: viewModel.onTapPrivacyPolicy,
                    ).dStyle(
                        .textWeak,
                    )
                    DButton(
                        title: l10n[
                            .buttonTermsAndConditions,
                        ],
                        action: viewModel.onTapTerms,
                    ).dStyle(
                        .textWeak,
                    )
                }
                .padding(
                    size.s16,
                )
                .padding(
                    .top,
                    topInset,
                )
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
        .environmentObject(
            viewModel,
        )
    }

    private var plans: some View {
        ForEach(
            viewModel.plans,
        ) { plan in
            DListButtonCard(
                title: viewModel.planTitle(
                    plan,
                ),
                description: viewModel.planPrice(
                    plan,
                ),
                action: { viewModel.onTapPlan(
                    plan,
                ) },
            )
            .disabled(
                viewModel.isLoading,
            )
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        if let error = viewModel.errorDescription {
            DText(
                error,
            ).dStyle(
                font: typography.textSmall,
                color: color.dangerDefault,
            )
            DButton(
                title: l10n[
                    .subscriptionPaywallRetryButton,
                ],
                action: viewModel.onTapRetry,
            ).dStyle(
                .textWeak,
            ).disabled(
                viewModel.isLoading,
            )
        }
    }
}
