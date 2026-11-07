#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 NewVersionState",
    ) {
        NewVersionPreviewView(
            state: NewVersionState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
