import SwiftUI

struct PhotoLibraryPickerBottomSheetView: View {
    @StateObject var viewModel: PhotoLibraryPickerViewModel

    init(
        viewModel: @autoclosure @escaping () -> PhotoLibraryPickerViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

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
