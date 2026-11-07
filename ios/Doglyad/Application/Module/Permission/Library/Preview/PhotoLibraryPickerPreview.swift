#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PhotoLibraryPickerState",
    ) {
        PhotoLibraryPickerPreviewView(
            state: PhotoLibraryPickerState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
