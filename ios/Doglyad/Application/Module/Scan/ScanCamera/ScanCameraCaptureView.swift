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
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                )
            }

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
            .padding(.vertical, size.s16)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .clipShape(
                        DRoundedCorner(
                            radius: size.adaptiveCornerRadius,
                            corners: [.topLeft, .topRight]
                        )
                    )
            )
        }
        .frame(maxWidth: .infinity)
        .animation(
            theme.animation,
            value: viewModel.isCaptureAvailable
        )
    }
}
