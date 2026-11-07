#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 StorageClearAllState",
    ) {
        StorageClearAllPreviewView(
            state: StorageClearAllState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
