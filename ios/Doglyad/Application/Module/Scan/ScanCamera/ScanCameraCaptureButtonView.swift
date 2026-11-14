import DoglyadUI
import SwiftUI

struct ScanCameraCaptureButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanCameraViewModel
    let isCapturing: Bool

    init(
        isCapturing: Bool,
    ) {
        self.isCapturing = isCapturing
    }

    var body: some View {
        switch viewModel.state {
        case _ as ScanCameraReadyState, _ as ScanCameraCaptureLoadingState:
            DButton(
                image: .camera,
                action: viewModel.onTapCapture,
                isLoading: isCapturing,
                isDisabled: !isCapturing && !viewModel.isCaptureFrameReady,
                accessibilityIdentifier: "scanCamera.capture",
            )
            .dStyle(
                .primaryCircle,
            )

        default: EmptyView()
        }
    }
}
