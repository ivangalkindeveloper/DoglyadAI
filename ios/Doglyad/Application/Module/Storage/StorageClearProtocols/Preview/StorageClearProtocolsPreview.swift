#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 StorageClearProtocolsState",
    ) {
        StorageClearProtocolsPreviewView(
            state: StorageClearProtocolsState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
