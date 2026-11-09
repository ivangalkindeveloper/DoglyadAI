#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PhotoRemarkDefaultState ModelRemark",
    ) {
        PhotoRemarkPreviewView(
            state: PhotoRemarkDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
