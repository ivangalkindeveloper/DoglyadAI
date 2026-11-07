#if DEBUG
    import Combine
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ScanCameraPreparingState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraPreparingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ScanCameraReadyState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ScanCameraCapturingState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraCapturingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ScanCameraStoppedState",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraStoppedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
