#if DEBUG
    import Combine
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "ScanCameraCapturingState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraCapturingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanCameraPreparingState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraPreparingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanCameraReadyState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanCameraStoppedState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraStoppedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
