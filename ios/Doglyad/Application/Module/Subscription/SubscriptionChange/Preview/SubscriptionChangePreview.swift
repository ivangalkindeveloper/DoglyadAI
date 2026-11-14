#if DEBUG
    import SwiftUI

    #Preview(
        "01 SubscriptionChangeDefaultState Robokassa",
    ) {
        SubscriptionChangePreviewView(
            state: SubscriptionChangeDefaultState(),
            source: .robokassa,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
    #Preview(
        "02 SubscriptionChangeDefaultState Apple",
    ) {
        SubscriptionChangePreviewView(
            state: SubscriptionChangeDefaultState(),
            source: .apple,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
