import PhotosUI
import SwiftUI

struct PhotoLibraryPickerRepresentableView: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onComplete: ([UIImage]) -> Void

    func makeUIViewController(
        context: Context
    ) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _: PHPickerViewController,
        context _: Context
    ) {}

    func makeCoordinator() -> PhotoLibraryPickerCoordinator {
        PhotoLibraryPickerCoordinator(onComplete: onComplete)
    }
}
