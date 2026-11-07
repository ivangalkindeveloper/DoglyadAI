#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PermissionState",
    ) {
        PermissionPreviewView(
            state: PermissionState(),
            kind: .camera,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 Permission · speech",
    ) {
        PermissionPreviewView(
            state: PermissionState(),
            kind: .speech,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 Permission · photoLibrary",
    ) {
        PermissionPreviewView(
            state: PermissionState(),
            kind: .photoLibrary,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
