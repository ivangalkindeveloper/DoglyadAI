#if DEBUG
    import SwiftUI

    #Preview(
        "01 SubscriptionRecoveryInitialState NoRecoveryKey",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SubscriptionRecoveryInitialState NoRecoveryKey ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 SubscriptionRecoveryKeyCreationLoadingState CreatingRecoveryKey",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryKeyCreationLoadingState(
                previousState: SubscriptionRecoveryInitialState(),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SubscriptionRecoveryKeyCreationLoadingState CreatingRecoveryKey ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryKeyCreationLoadingState(
                previousState: SubscriptionRecoveryInitialState(),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 SubscriptionRecoverySuccessState RecoveryKeyCreated",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoverySuccessState(
                key: "Preview-MixedCase-Recovery-Key",
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 SubscriptionRecoverySuccessState RecoveryKeyCreated ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoverySuccessState(
                key: "Preview-MixedCase-Recovery-Key",
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "07 SubscriptionRecoveryRestoreLoadingState RestoringWithKey",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryRestoreLoadingState(
                previousState: SubscriptionRecoverySuccessState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 SubscriptionRecoveryRestoreLoadingState RestoringWithKey ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryRestoreLoadingState(
                previousState: SubscriptionRecoverySuccessState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "09 SubscriptionRecoveryErrorState RecoveryFailedWithoutKey",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryErrorState(
                previousState: SubscriptionRecoveryInitialState(),
                errorDescription: L10NPreviewFactory.make().text(
                    .subscriptionRecoveryFailedDescription,
                ),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "10 SubscriptionRecoveryErrorState RecoveryFailedWithoutKey ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryErrorState(
                previousState: SubscriptionRecoveryInitialState(),
                errorDescription: L10NPreviewFactory.make().text(
                    .subscriptionRecoveryFailedDescription,
                ),
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "11 SubscriptionRecoveryErrorState RecoveryFailedWithRetainedKey",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryErrorState(
                previousState: SubscriptionRecoverySuccessState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
                errorDescription: "Не удалось восстановить подписку.",
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "12 SubscriptionRecoveryErrorState RecoveryFailedWithRetainedKey ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryErrorState(
                previousState: SubscriptionRecoverySuccessState(
                    key: "Preview-MixedCase-Recovery-Key",
                ),
                errorDescription: "Не удалось восстановить подписку.",
            ),
        )
        .previewable(
            container: ManageSubscriptionPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
