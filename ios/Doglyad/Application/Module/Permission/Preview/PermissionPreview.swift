#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PermissionDefaultState CameraAccess",
    ) {
        PermissionPreviewView(
            state: PermissionDefaultState(),
            kind: .camera,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 PermissionDefaultState MicrophoneAccess",
    ) {
        PermissionPreviewView(
            state: PermissionDefaultState(),
            kind: .speech,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 PermissionDefaultState PhotoLibraryAccess",
    ) {
        PermissionPreviewView(
            state: PermissionDefaultState(),
            kind: .photoLibrary,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
