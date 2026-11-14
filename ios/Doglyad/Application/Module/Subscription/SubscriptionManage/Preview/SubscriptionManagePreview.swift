#if DEBUG
    import SwiftUI

    #Preview(
        "01 SubscriptionManageCatalogLoadingState LoadingCatalog",
    ) {
        SubscriptionManagePreviewView(
            scenario: .loading,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "02 SubscriptionManageCatalogLoadingState LoadingCatalog ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .loading,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 SubscriptionManageErrorState CatalogRequestFailed",
    ) {
        SubscriptionManagePreviewView(
            scenario: .failed,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "04 SubscriptionManageInactiveState NoSubscription",
    ) {
        SubscriptionManagePreviewView(
            scenario: .inactive,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "05 SubscriptionManageInactiveState NoSubscription ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .inactive,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "06 SubscriptionManageActiveState AppleBase",
    ) {
        SubscriptionManagePreviewView(
            scenario: .appleBase,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "07 SubscriptionManageActiveState AppleBase ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .appleBase,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "08 SubscriptionManageActiveState RobokassaBase",
    ) {
        SubscriptionManagePreviewView(
            scenario: .robokassaBase,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "09 SubscriptionManageActiveState RobokassaBase ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .robokassaBase,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "10 SubscriptionManageActiveState ApplePro",
    ) {
        SubscriptionManagePreviewView(
            scenario: .applePro,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "11 SubscriptionManageActiveState ApplePro ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .applePro,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "12 SubscriptionManageActiveState RobokassaPro",
    ) {
        SubscriptionManagePreviewView(
            scenario: .robokassaPro,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "13 SubscriptionManageActiveState RobokassaPro ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .robokassaPro,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "14 SubscriptionManageActiveState AppleRenewalDisabled",
    ) {
        SubscriptionManagePreviewView(
            scenario: .appleRenewalOff,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "15 SubscriptionManageActiveState AppleRenewalDisabled ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .appleRenewalOff,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "16 SubscriptionManageActiveState RobokassaRenewalDisabled",
    ) {
        SubscriptionManagePreviewView(
            scenario: .renewalOff,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "17 SubscriptionManageActiveState RobokassaRenewalDisabled ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .renewalOff,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "18 SubscriptionManageActiveState AutoRenewalDisabledSuccess",
    ) {
        SubscriptionManagePreviewView(
            scenario: .autoRenewalDisabledSuccess,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "19 SubscriptionManageActiveState AutoRenewalDisabledSuccess ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .autoRenewalDisabledSuccess,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
    #Preview(
        "20 SubscriptionManageActiveState AccessRecoveredSuccess",
    ) {
        SubscriptionManagePreviewView(
            scenario: .recoveredAccess,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "21 SubscriptionManageActiveState AccessRecoveredSuccess ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .recoveredAccess,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
    #Preview(
        "22 SubscriptionManageActiveState PurchaseCompletedSuccess",
    ) {
        SubscriptionManagePreviewView(
            scenario: .purchaseCompletedSuccess,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "23 SubscriptionManageActiveState PurchaseCompletedSuccess ScrollEnd",
    ) {
        SubscriptionManagePreviewView(
            scenario: .purchaseCompletedSuccess,
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
