#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "NewVersionState",
    ) {
        NewVersionPreviewView(
            state: NewVersionState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
