import PhotosUI
import UIKit

final class PhotoLibraryPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    private let onComplete: ([UIImage]) -> Void

    init(
        onComplete: @escaping ([UIImage]) -> Void
    ) {
        self.onComplete = onComplete
    }

    func picker(
        _: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        let providers = results
            .map(\.itemProvider)
            .filter { $0.canLoadObject(ofClass: UIImage.self) }

        guard !providers.isEmpty else {
            onComplete([])
            return
        }

        var images = [UIImage?](repeating: nil, count: providers.count)
        let lock = NSLock()
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            group.enter()
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    lock.lock()
                    images[index] = image
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [onComplete] in
            onComplete(images.compactMap { $0 })
        }
    }
}
