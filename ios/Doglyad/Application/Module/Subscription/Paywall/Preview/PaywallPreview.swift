#if DEBUG
    import SwiftUI

    #Preview(
        "01 PaywallCatalogLoadingState LoadingPlans",
    ) {
        PaywallPreviewView(
            state: PaywallCatalogLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 PaywallCatalogLoadingState LoadingPlans ScrollEnd",
    ) {
        PaywallPreviewView(
            state: PaywallCatalogLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 PaywallCatalogErrorState PlansRequestFailed",
    ) {
        PaywallPreviewView(
            state: PaywallCatalogErrorState(
                errorDescription: ModulePreviewFactory.makeContainer().l10n.text(
                    .errorUnknownDescription,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 PaywallSuccessState AvailablePlans",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 PaywallSuccessState AvailablePlans ScrollEnd",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "06 PaywallSuccessState AutoRenewalOff",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent.copyWith(
                isAutoRenewing: false,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 PaywallSuccessState AutoRenewalOff ScrollEnd",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent.copyWith(
                isAutoRenewing: false,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "08 PaywallPurchaseLoadingState PurchasingOrRestoring",
    ) {
        PaywallPreviewView(
            state: PaywallPurchaseLoadingState(
                content: ModulePreviewFactory.paywallContent,
                plan: ModulePreviewFactory.paywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "09 PaywallPurchaseLoadingState PurchasingOrRestoring ScrollEnd",
    ) {
        PaywallPreviewView(
            state: PaywallPurchaseLoadingState(
                content: ModulePreviewFactory.paywallContent,
                plan: ModulePreviewFactory.paywallPlan,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "10 PaywallOperationErrorState PaymentOperationFailed",
    ) {
        PaywallPreviewView(
            state: PaywallOperationErrorState(
                errorDescription: ModulePreviewFactory.makeContainer().l10n.text(
                    .subscriptionPurchaseErrorDescription,
                ),
                previousState: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "11 PaywallOperationErrorState PaymentOperationFailed ScrollEnd",
    ) {
        PaywallPreviewView(
            state: PaywallOperationErrorState(
                errorDescription: ModulePreviewFactory.makeContainer().l10n.text(
                    .subscriptionPurchaseErrorDescription,
                ),
                previousState: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "12 PaywallPaymentPendingState UnconfirmedPayment",
    ) {
        PaywallPreviewView(
            state: PaywallPaymentPendingState(
                copying: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "13 PaywallPaymentPendingState UnconfirmedPayment ScrollEnd",
    ) {
        PaywallPreviewView(
            state: PaywallPaymentPendingState(
                copying: ModulePreviewFactory.paywallContent,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        ).previewScrollToEnd()
    }
    #Preview(
        "14 PaywallSuccessState PurchaseCompletedMessage",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent,
            isPurchaseSuccessPresented: true,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "15 PaywallSuccessState PurchaseCompletedMessage ScrollEnd",
    ) {
        PaywallPreviewView(
            state: ModulePreviewFactory.paywallContent,
            isPurchaseSuccessPresented: true,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
