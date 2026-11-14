#if DEBUG
    import SwiftUI

    #Preview(
        "01 SubscriptionRecoveryInitialState EnterRecoveryKey",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
        ).previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "02 SubscriptionRecoveryInitialState EnterRecoveryKey ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
        ).previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        ).previewScrollToEnd()
    }
    #Preview(
        "03 SubscriptionRecoveryRestoreLoadingState RestoringAccess",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryRestoreLoadingState(),
        ).previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "04 SubscriptionRecoveryRestoreLoadingState RestoringAccess ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryRestoreLoadingState(),
        ).previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        ).previewScrollToEnd()
    }
    #Preview(
        "05 SubscriptionRecoveryInitialState InvalidKeyRetained",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
            isErrorPresented: true,
            input: "DEMO-KEY",
        ).previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "06 SubscriptionRecoveryInitialState InvalidKeyRetained ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
            isErrorPresented: true,
            input: "DEMO-KEY",
        ).previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        ).previewScrollToEnd()
    }

    #Preview(
        "07 SubscriptionRecoveryInitialState NoActiveSubscription",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
            isNoActivePresented: true,
            input: "INACTIVE-DEMO-KEY",
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "08 SubscriptionRecoveryInitialState NoActiveSubscription ScrollEnd",
    ) {
        SubscriptionRecoveryPreviewView(
            state: SubscriptionRecoveryInitialState(),
            isNoActivePresented: true,
            input: "INACTIVE-DEMO-KEY",
        )
        .previewable(
            container: SubscriptionManagePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
