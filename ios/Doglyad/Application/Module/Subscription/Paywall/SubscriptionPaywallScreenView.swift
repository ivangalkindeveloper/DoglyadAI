import DoglyadUI
import SwiftUI

struct SubscriptionPaywallScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionPaywallViewModel

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as SubscriptionPaywallRestoringState, _ as SubscriptionPaywallPurchasingState, _ as SubscriptionPaywallLoadingState: true
        default: false
        }
        let onClose: (() -> Void)? = switch viewModel.isDismissible {
        case true: viewModel.onTapClose
        case false: nil
        }
        DScreen(
            title: l10n[
                .subscriptionPaywallTitle,
            ],
            onTapBack: onClose,
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
                    SubscriptionPaywallPlansView()
                    SubscriptionPaywallErrorView()
                    DButton(
                        title: l10n[
                            .subscriptionPaywallRestoreButton,
                        ],
                        action: viewModel.onTapRestore,
                        isLoading: isProcessing,
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
                }.padding(
                    size.s16,
                ).padding(
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
}
