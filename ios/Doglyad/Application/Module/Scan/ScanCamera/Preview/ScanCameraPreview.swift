#if DEBUG
    import Combine
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ScanCameraPreparationLoadingState PreparingCamera",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraPreparationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ScanCameraReadyState CameraReady",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraReadyState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ScanCameraCaptureLoadingState CapturingPhoto",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraCaptureLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ScanCameraStoppedState CameraStopped",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraStoppedState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 ScanCameraReadyState MultiplePhotos",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraReadyState(),
            photos: Array(
                ModulePreviewFactory.cameraPhotos.prefix(
                    3,
                ),
            ),
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ScanCameraReadyState PhotoLimitReached",
    ) {
        ScanCameraPreviewView(
            state: ScanCameraReadyState(),
            photos: ModulePreviewFactory.cameraPhotos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
