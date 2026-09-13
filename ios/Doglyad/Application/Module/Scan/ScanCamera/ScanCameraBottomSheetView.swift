import DoglyadUI
import SwiftUI

struct ScanCameraBottomSheetView: View {
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    @StateObject var viewModel: ScanCameraViewModel

    var body: some View {
        DBottomSheet(
            type: .blur,
            title: .scanCameraTitle,
            fraction: 0.9
        ) { _, _ in
            ZStack {
                ScanCameraPreviewView()

                VStack(
                    spacing: .zero
                ) {
                    Spacer()
                    ScanCameraCaptureView()
                        .padding(.bottom, size.s16)
                }
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .environmentObject(viewModel)
    }
}
