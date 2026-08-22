import DoglyadUI
import SwiftUI

struct ScanCaptureView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @EnvironmentObject private var viewModel: ScanViewModel

    var body: some View {
        VStack(
            spacing: size.s8
        ) {
            HStack(
                spacing: size.s16
            ) {
                if viewModel.isCaptureAvailable {
                    DButton(
                        image: viewModel.captureIcon,
                        action: viewModel.onTapCapture,
                        isLoading: viewModel.cameraController.isCapturing,
                        isDisabled: viewModel.isLoading
                    )
                    .dStyle(.primaryCircle)
                }

                if viewModel.isSpeechButtonVisible {
                    DButton(
                        image: .microphone,
                        action: viewModel.onTapSpeech,
                        isDisabled: viewModel.isLoading
                    )
                    .dStyle(.primaryCircle)
                    .paidBadge(.formCompletionViaMicrophone)
                }
            }

            if viewModel.isCaptureAvailable {
                DText(.scanCaptureDescription)
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleLine,
                        alignment: .center
                    )
            }
        }
        .padding(size.s8)
        .padding(.bottom, viewModel.sheetController.isSheetVisible ? size.s128 : .zero)
        .animation(
            theme.animation,
            value: viewModel.cameraController.isRunning
        )
        .animation(
            theme.animation,
            value: viewModel.sheetController.currentPosition
        )
    }
}

#Preview {
    ScanCaptureView()
}
