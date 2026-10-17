import DoglyadCamera
import DoglyadUI
import SwiftUI

struct ScanCameraPreviewView: DViewProtocol {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanCameraViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case _ as ScanCameraPreparingState:
                color.grayscaleBackground
                    .dShimmer(
                        cornerRadius: .zero,
                    )
                    .transition(
                        .opacity,
                    )
            default:
                DCameraView(
                    controller: viewModel.cameraController,
                )
                .onGeometryChange(
                    for: CGRect.self,
                ) { proxy in
                    proxy.frame(
                        in: .global,
                    )
                } action: { frame in
                    viewModel.updatePreviewFrame(
                        frame,
                    )
                }
                .transition(
                    .opacity,
                )
            }
        }
        .ignoresSafeArea()
    }
}
