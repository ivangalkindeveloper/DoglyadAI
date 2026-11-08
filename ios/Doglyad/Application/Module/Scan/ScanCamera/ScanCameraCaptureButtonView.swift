import DoglyadUI
import SwiftUI

struct ScanCameraCaptureButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanCameraViewModel
    let isCapturing: Bool

    var body: some View {
        switch viewModel.state {
        case _ as ScanCameraReadyState, _ as ScanCameraCaptureLoadingState:
            DButton(
                image: .camera,
                accessibilityIdentifier: "scanCamera.capture",
                action: viewModel.onTapCapture,
                isLoading: isCapturing,
                isDisabled: !viewModel.isCaptureFrameReady,
            )
            .dStyle(
                .primaryCircle,
            )

        default: EmptyView()
        }
    }
}
