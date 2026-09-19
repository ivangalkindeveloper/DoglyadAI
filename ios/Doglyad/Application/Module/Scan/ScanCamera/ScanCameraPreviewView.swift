import DoglyadCamera
import DoglyadUI
import SwiftUI

struct ScanCameraPreviewView: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanCameraViewModel

    var body: some View {
        Group {
            if viewModel.cameraController.isLoading {
                color.grayscaleBackground
                    .dShimmer(cornerRadius: .zero)
                    .transition(.opacity)
            } else {
                ZStack {
                    DCameraView(
                        controller: viewModel.cameraController
                    )

                    ScanCameraFrameView()
                        .padding(.bottom, size.s136)
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(
            theme.animation,
            value: viewModel.cameraController.isLoading
        )
    }
}
