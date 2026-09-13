import DoglyadUI
import SwiftUI

struct ScanCameraCaptureView: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanCameraViewModel

    var body: some View {
        VStack(
            spacing: size.s8
        ) {
            if viewModel.isCaptureAvailable {
                DButton(
                    image: .camera,
                    action: viewModel.onTapCapture,
                    isLoading: viewModel.cameraController.isCapturing
                )
                .dStyle(.primaryCircle)

                DText(.scanCaptureDescription)
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleLine,
                        alignment: .center
                    )
            }

            ScanPhotosView(
                photos: viewModel.photos,
                photoMaxCount: viewModel.photoMaxCount,
                onTapDelete: viewModel.onTapDeletePhoto
            )
        }
        .padding(size.s8)
        .animation(
            theme.animation,
            value: viewModel.cameraController.isRunning
        )
    }
}
