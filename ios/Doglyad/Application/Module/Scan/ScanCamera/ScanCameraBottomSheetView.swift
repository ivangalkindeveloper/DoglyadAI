import DoglyadUI
import SwiftUI

struct ScanCameraBottomSheetView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanCameraViewModel

    var body: some View {
        DBottomSheet(
            type: .blur,
            title: .scanCameraTitle,
            fraction: 0.9
        ) { toolbarInset, bottomInset in
            ZStack(
                alignment: .bottom
            ) {
                ScanCameraPreviewView()

                VStack(
                    spacing: .zero
                ) {
                    if !viewModel.cameraController.isLoading {
                        ScanCameraFrameView(
                            onFrameChanged: viewModel.updateCaptureFrame
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                    } else {
                        Spacer()
                    }

                    if viewModel.isCaptureAvailable {
                        DButton(
                            image: .camera,
                            action: viewModel.onTapCapture,
                            isLoading: viewModel.cameraController.isCapturing,
                            isDisabled: !viewModel.isCaptureFrameReady
                        )
                        .dStyle(.primaryCircle)
                    }
                }
                .padding(.top, toolbarInset)
                .padding(size.s16)
                .padding(.bottom, bottomInset)
                .animation(
                    theme.animation,
                    value: bottomInset
                )
            }
        } bottom: {
            VStack(
                spacing: size.s8
            ) {
                if viewModel.isCaptureAvailable {
                    DText(.scanCaptureDescription)
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleLine,
                            alignment: .center
                        )
                        .padding(.horizontal, size.adaptiveCornerRadius / 2)
                        .safeAreaPadding(.bottom, viewModel.photos.isEmpty ? nil : .zero)
                }

                ScanCameraPhotoListView()
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            viewModel.onAppear()
            viewModel.onCameraAppear()
        }
        .onDisappear(perform: viewModel.onDisappear)
        .environmentObject(viewModel)
    }
}
