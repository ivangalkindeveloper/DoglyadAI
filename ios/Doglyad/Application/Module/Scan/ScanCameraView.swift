import DoglyadCamera
import DoglyadUI
import SwiftUI

struct ScanCameraView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        Group {
            if viewModel.cameraController.isLoading {
                color.grayscaleBackground
                    .dShimmer(cornerRadius: 0)
            } else {
                ZStack {
                    DCameraView(
                        controller: viewModel.cameraController
                    )
                    .if(!viewModel.cameraController.isRunning) { view in
                        view
                            .blur(radius: size.s16)
                    }

                    if viewModel.cameraController.isRunning {
                        ScanFrameView()
                    } else {
                        VStack(
                            alignment: .center
                        ) {
                            DText(
                                .scanTurnedOffCameraDescription
                            )
                            .dStyle(
                                font: typography.textSmall,
                                color: color.grayscaleLine,
                                alignment: .center
                            )
                            .padding(.bottom, size.s16)

                            if !viewModel.isPhotoFilling {
                                DButton(
                                    title: .buttonCameraTurnOn,
                                    action: viewModel.onTapCameraTurnOn
                                )
                                .dStyle(.chip)
                            }
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
