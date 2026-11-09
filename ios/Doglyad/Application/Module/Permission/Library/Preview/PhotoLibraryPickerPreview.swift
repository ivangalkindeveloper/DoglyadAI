#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PhotoLibraryPickerDefaultState PhotoLibrary",
    ) {
        PhotoLibraryPickerPreviewView(
            state: PhotoLibraryPickerDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
