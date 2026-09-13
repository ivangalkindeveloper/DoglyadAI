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
        ) { _, _ in
            ZStack(
                alignment: .bottom
            ) {
                ScanCameraPreviewView()

                ScanCameraCaptureView()
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .environmentObject(viewModel)
    }
}
