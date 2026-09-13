import DoglyadCamera
import DoglyadUI
import SwiftUI

struct ScanCameraPreviewView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @EnvironmentObject private var viewModel: ScanCameraViewModel

    var body: some View {
        Group {
            if viewModel.cameraController.isLoading {
                color.grayscaleBackground
                    .dShimmer(cornerRadius: .zero)
            } else {
                ZStack {
                    DCameraView(
                        controller: viewModel.cameraController
                    )
                    .if(!viewModel.cameraController.isRunning) { view in
                        view.blur(radius: size.s16)
                    }

                    if viewModel.cameraController.isRunning {
                        ScanCameraFrameView()
                    } else {
                        VStack(
                            alignment: .center
                        ) {
                            DText(.scanTurnedOffCameraDescription)
                                .dStyle(
                                    font: typography.textSmall,
                                    color: color.grayscaleLine,
                                    alignment: .center
                                )
                                .padding(.bottom, size.s16)

                            DButton(
                                title: .buttonCameraTurnOn,
                                action: viewModel.onTapCameraTurnOn
                            )
                            .dStyle(.chip)
                        }
                        .padding(size.s32)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .animation(
            theme.animation,
            value: viewModel.cameraController.isRunning
        )
    }
}
