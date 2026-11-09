import DoglyadUI
import SwiftUI

struct ScanCameraBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: ScanCameraViewModel

    var body: some View {
        let isCapturing = switch viewModel.state {
        case _ as ScanCameraCaptureLoadingState: true
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
                ScanCameraFeedView()

                VStack(
                    spacing: .zero,
                ) {
                    ScanCameraFrameStateView()

                    ScanCameraCaptureButtonView(
                        isCapturing: isCapturing,
                    )
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
                ScanCameraDescriptionView()

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
