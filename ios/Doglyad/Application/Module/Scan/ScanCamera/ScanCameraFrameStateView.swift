import DoglyadUI
import SwiftUI

struct ScanCameraFrameStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanCameraViewModel

    init() {}

    var body: some View {
        switch viewModel.state {
        case _ as ScanCameraPreparationLoadingState: Spacer()
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
    }
}
