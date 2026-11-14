#if DEBUG
    import SwiftUI

    #Preview(
        "01 SubscriptionAutoRenewalDisablingInitialState ConfirmDisabling",
    ) {
        SubscriptionAutoRenewalDisablingPreviewView(
            state: SubscriptionAutoRenewalDisablingInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "02 SubscriptionAutoRenewalDisablingLoadingState Disabling",
    ) {
        SubscriptionAutoRenewalDisablingPreviewView(
            state: SubscriptionAutoRenewalDisablingLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
