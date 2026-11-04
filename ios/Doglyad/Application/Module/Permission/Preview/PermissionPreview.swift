#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "PermissionState",
    ) {
        PermissionPreviewView(
            state: PermissionState(),
            kind: .camera,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Permission · speech",
    ) {
        PermissionPreviewView(
            state: PermissionState(),
            kind: .speech,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "Permission · photoLibrary",
    ) {
        PermissionPreviewView(
            state: PermissionState(),
            kind: .photoLibrary,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
