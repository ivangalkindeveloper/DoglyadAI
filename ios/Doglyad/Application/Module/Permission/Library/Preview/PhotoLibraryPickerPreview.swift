#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "PhotoLibraryPickerState",
    ) {
        PhotoLibraryPickerPreviewView(
            state: PhotoLibraryPickerState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
