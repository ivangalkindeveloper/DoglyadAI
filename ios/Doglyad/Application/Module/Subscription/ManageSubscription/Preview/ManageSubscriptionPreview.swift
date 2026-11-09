#if DEBUG
    import SwiftUI

    #Preview(
        "01 ManageSubscriptionCatalogLoadingState LoadingCatalog",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .loading,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "02 ManageSubscriptionCatalogLoadingState LoadingCatalog ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .loading,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 ManageSubscriptionErrorState CatalogRequestFailed",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .failed,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "04 ManageSubscriptionSuccessState NoSubscription",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .inactive,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "05 ManageSubscriptionSuccessState NoSubscription ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .inactive,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "06 ManageSubscriptionSuccessState AppleBase",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .appleBase,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "07 ManageSubscriptionSuccessState AppleBase ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .appleBase,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "08 ManageSubscriptionSuccessState YooKassaBase",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .yooKassaBase,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "09 ManageSubscriptionSuccessState YooKassaBase ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .yooKassaBase,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "10 ManageSubscriptionSuccessState ApplePro",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .applePro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "11 ManageSubscriptionSuccessState ApplePro ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .applePro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "12 ManageSubscriptionSuccessState YooKassaPro",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .yooKassaPro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "13 ManageSubscriptionSuccessState YooKassaPro ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .yooKassaPro,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "14 ManageSubscriptionRefreshLoadingState RefreshingSubscription",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .updating,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "15 ManageSubscriptionRefreshLoadingState RefreshingSubscription ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .updating,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "16 ManageSubscriptionSuccessState AppleRenewalDisabled",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .appleRenewalOff,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "17 ManageSubscriptionSuccessState AppleRenewalDisabled ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .appleRenewalOff,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "18 ManageSubscriptionSuccessState YooKassaRenewalDisabled",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .renewalOff,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "19 ManageSubscriptionSuccessState YooKassaRenewalDisabled ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .renewalOff,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "20 ManageSubscriptionErrorState OperationFailed",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .operationFailed,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "21 ManageSubscriptionErrorState OperationFailed ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .operationFailed,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "22 ManageSubscriptionRestoreLoadingState RestoringPurchases",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .restoring,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "23 ManageSubscriptionRestoreLoadingState RestoringPurchases ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .restoring,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "24 ManageSubscriptionManagementLoadingState ManagingRenewal",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .managing,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "25 ManageSubscriptionManagementLoadingState ManagingRenewal ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .managing,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "26 ManageSubscriptionRefundLoadingState RequestingRefund",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .refunding,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
    }

    #Preview(
        "27 ManageSubscriptionRefundLoadingState RequestingRefund ScrollEnd",
    ) {
        ManageSubscriptionPreviewView(
            scenario: .refunding,
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(
                code: "ru",
            ),
        )
        .previewScrollToEnd()
    }
#endif
