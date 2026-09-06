import SwiftUI

struct PhotoLibraryPickerView: View {
    @StateObject var viewModel: PhotoLibraryPickerViewModel

    var body: some View {
        PhotoLibraryPickerRepresentableView(
            selectionLimit: viewModel.selectionLimit,
            onComplete: viewModel.onComplete
        )
        .onAppear(perform: viewModel.onAppear)
    }
}
