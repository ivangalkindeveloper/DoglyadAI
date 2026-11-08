#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 PermissionDefaultState",
    ) {
        PermissionPreviewView(
            state: PermissionDefaultState(),
            kind: .camera,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 Permission · speech",
    ) {
        PermissionPreviewView(
            state: PermissionDefaultState(),
            kind: .speech,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 Permission · photoLibrary",
    ) {
        PermissionPreviewView(
            state: PermissionDefaultState(),
            kind: .photoLibrary,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
