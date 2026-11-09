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
                    .subscriptionOfferingsUnavailableDescription,
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
        "06 PaywallPurchaseLoadingState PurchasingOrRestoring",
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
        "07 PaywallPurchaseLoadingState PurchasingOrRestoring ScrollEnd",
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
        "08 PaywallOperationErrorState PaymentOperationFailed",
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
        "09 PaywallOperationErrorState PaymentOperationFailed ScrollEnd",
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

#endif
