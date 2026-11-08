#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 StorageClearProtocolsDefaultState",
    ) {
        StorageClearProtocolsPreviewView(
            state: StorageClearProtocolsDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
