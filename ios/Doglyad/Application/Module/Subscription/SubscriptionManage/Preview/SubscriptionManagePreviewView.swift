#if DEBUG
    import Router
    import SwiftUI

    struct SubscriptionManagePreviewView: View {
        @EnvironmentObject private var container: DependencyContainer
        @EnvironmentObject private var router: DRouter
        let scenario: SubscriptionManagePreviewScenario

        init(
            scenario: SubscriptionManagePreviewScenario,
        ) {
            self.scenario = scenario
        }

        var body: some View {
            let (isErrorPresented, successTitleKey, successDescriptionKey): (Bool, L10NKey?, L10NKey?) = switch scenario {
            case .failed, .operationFailed: (true, nil, nil)
            case .autoRenewalDisabledSuccess: (false, .subscriptionAutoRenewalDisablingSuccessTitle, .subscriptionAutoRenewalDisablingSuccessDescription)
            case .recoveredAccess: (false, .subscriptionRecoverySuccessTitle, .subscriptionRecoverySuccessDescription)
            case .purchaseCompletedSuccess: (false, .paywallPurchaseSuccessTitle, .paywallPurchaseSuccessDescription)
            default: (false, nil, nil)
            }

            let model = SubscriptionManagePreviewFactory.makeViewModel(
                container: container,
                router: router,
                status: SubscriptionManagePreviewFactory.status(
                    for: scenario,
                ),
            )

            SubscriptionManageScreenView(
                viewModel: model,
            )
            .previewError(
                isPresented: isErrorPresented,
            )
            .previewMessage(
                type: .success,
                title: successTitleKey,
                description: successDescriptionKey,
            )
            .id(
                scenario,
            )
            .task {
                await SubscriptionManagePreviewFactory.apply(
                    scenario,
                    to: model,
                )
            }
        }
    }
#endif
