#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PhotoRemarkState",
    ) {
        PhotoRemarkPreviewView(
            state: PhotoRemarkState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
