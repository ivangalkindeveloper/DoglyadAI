import SwiftUI

struct PhotoLibraryPickerBottomSheetView: View {
    @StateObject var viewModel: PhotoLibraryPickerViewModel

    var body: some View {
        PhotoLibraryPickerRepresentableView(
            selectionLimit: viewModel.selectionLimit,
            onComplete: viewModel.onComplete,
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
