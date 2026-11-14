import DoglyadUI
import SwiftUI

struct ScanCameraDescriptionView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanCameraViewModel

    init() {}

    var body: some View {
        switch viewModel.state {
        case _ as ScanCameraReadyState, _ as ScanCameraCaptureLoadingState:
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
    }
}
