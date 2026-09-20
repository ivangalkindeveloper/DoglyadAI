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
                DCameraView(
                    controller: viewModel.cameraController
                )
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    viewModel.updatePreviewFrame(frame)
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
