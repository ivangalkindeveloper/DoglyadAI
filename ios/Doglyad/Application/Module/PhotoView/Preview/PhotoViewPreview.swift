#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "PhotoViewContentState",
    ) {
        PhotoViewPreviewView(
            state: PhotoViewContentState(),
            photos: ModulePreviewFactory.photos,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "PhotoViewEmptyState",
    ) {
        PhotoViewPreviewView(
            state: PhotoViewEmptyState(),
            photos: [],
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
