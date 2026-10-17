import DoglyadUI
import SwiftUI

struct ScanCameraBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: ScanCameraViewModel

    var body: some View {
        let isCapturing = switch viewModel.state {
        case _ as ScanCameraCapturingState: true
        default: false
        }

        DBottomSheet(
            type: .blur,
            title: l10n[
                .scanCameraTitle,
            ],
            fraction: 0.9,
        ) { toolbarInset, bottomInset in
            ZStack(
                alignment: .bottom,
            ) {
                ScanCameraPreviewView()

                VStack(
                    spacing: .zero,
                ) {
                    switch viewModel.state {
                    case _ as ScanCameraPreparingState: Spacer()
                    default:
                        ScanCameraFrameView(
                            onFrameChanged: viewModel.updateCaptureFrame,
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center,
                        )
                    }

                    switch viewModel.state {
                    case _ as ScanCameraReadyState, _ as ScanCameraCapturingState:
                        DButton(
                            image: .camera,
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
                .padding(
                    .top,
                    toolbarInset,
                )
                .padding(
                    size.s16,
                )
                .padding(
                    .bottom,
                    bottomInset,
                )
                .animation(
                    theme.animation,
                    value: bottomInset,
                )
            }
        } bottom: {
            VStack(
                spacing: size.s8,
            ) {
                switch viewModel.state {
                case _ as ScanCameraReadyState, _ as ScanCameraCapturingState:
                    DText(
                        l10n[
                            .scanCaptureDescription,
                        ],
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleLine,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.adaptiveCornerRadius / 2,
                    )
                    .safeAreaPadding(
                        .bottom,
                        viewModel.photos.isEmpty ? nil : .zero,
                    )
                default: EmptyView()
                }

                ScanCameraPhotoListView()
            }
            .frame(
                maxWidth: .infinity,
            )
        }
        .onAppear {
            viewModel.onAppear()
            viewModel.onCameraAppear()
        }
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
