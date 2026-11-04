#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "PhotoRemarkState",
    ) {
        PhotoRemarkPreviewView(
            state: PhotoRemarkState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
