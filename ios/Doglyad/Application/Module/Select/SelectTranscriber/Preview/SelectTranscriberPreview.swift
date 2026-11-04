#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SelectTranscriberState",
    ) {
        SelectTranscriberPreviewView(
            state: SelectTranscriberState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
