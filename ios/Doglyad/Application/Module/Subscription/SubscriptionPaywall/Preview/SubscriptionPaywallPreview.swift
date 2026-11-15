#if DEBUG
    import SwiftUI

    #Preview(
        "01 SubscriptionPaywallCatalogLoadingState LoadingPlans",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallCatalogLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SubscriptionPaywallCatalogLoadingState LoadingPlans ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallCatalogLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 SubscriptionPaywallCatalogErrorState PlansRequestFailed",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallCatalogErrorState(
                errorDescription: ModulePreviewFactory.makeContainer().l10n.text(
                    .errorUnknownDescription,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SubscriptionPaywallSuccessState AvailablePlans",
    ) {
        SubscriptionPaywallPreviewView(
            state: ModulePreviewFactory.subscriptionPaywallContent,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 SubscriptionPaywallSuccessState AvailablePlans ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: ModulePreviewFactory.subscriptionPaywallContent,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "06 SubscriptionPaywallSuccessState StoreKitPrices",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallPreviewFactory.storeKitContent,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 SubscriptionPaywallSuccessState StoreKitPrices ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallPreviewFactory.storeKitContent,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "08 SubscriptionPaywallSuccessState AutoRenewalOff",
    ) {
        SubscriptionPaywallPreviewView(
            state: ModulePreviewFactory.subscriptionPaywallContent.copyWith(
                isAutoRenewing: false,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "09 SubscriptionPaywallSuccessState AutoRenewalOff ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: ModulePreviewFactory.subscriptionPaywallContent.copyWith(
                isAutoRenewing: false,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "10 SubscriptionPaywallPurchaseLoadingState PurchasingOrRestoring",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallPurchaseLoadingState(
                content: ModulePreviewFactory.subscriptionPaywallContent,
                plan: ModulePreviewFactory.subscriptionPaywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "11 SubscriptionPaywallPurchaseLoadingState PurchasingOrRestoring ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallPurchaseLoadingState(
                content: ModulePreviewFactory.subscriptionPaywallContent,
                plan: ModulePreviewFactory.subscriptionPaywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "12 SubscriptionPaywallOperationErrorState PaymentOperationFailed",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallOperationErrorState(
                errorDescription: ModulePreviewFactory.makeContainer().l10n.text(
                    .subscriptionPurchaseErrorDescription,
                ),
                previousState: ModulePreviewFactory.subscriptionPaywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "13 SubscriptionPaywallOperationErrorState PaymentOperationFailed ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallOperationErrorState(
                errorDescription: ModulePreviewFactory.makeContainer().l10n.text(
                    .subscriptionPurchaseErrorDescription,
                ),
                previousState: ModulePreviewFactory.subscriptionPaywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "14 SubscriptionPaywallPaymentPendingState UnconfirmedPayment",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallPaymentPendingState(
                copying: ModulePreviewFactory.subscriptionPaywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "15 SubscriptionPaywallPaymentPendingState UnconfirmedPayment ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: SubscriptionPaywallPaymentPendingState(
                copying: ModulePreviewFactory.subscriptionPaywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        ).previewScrollToEnd()
    }
    #Preview(
        "16 SubscriptionPaywallSuccessState PurchaseCompletedMessage",
    ) {
        SubscriptionPaywallPreviewView(
            state: ModulePreviewFactory.subscriptionPaywallContent,
            isPurchaseSuccessPresented: true,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "17 SubscriptionPaywallSuccessState PurchaseCompletedMessage ScrollEnd",
    ) {
        SubscriptionPaywallPreviewView(
            state: ModulePreviewFactory.subscriptionPaywallContent,
            isPurchaseSuccessPresented: true,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
