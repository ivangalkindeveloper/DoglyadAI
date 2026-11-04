#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "StorageClearAllState",
    ) {
        StorageClearAllPreviewView(
            state: StorageClearAllState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
