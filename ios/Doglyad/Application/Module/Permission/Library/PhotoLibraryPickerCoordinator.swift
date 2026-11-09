import PhotosUI
import UIKit

final class PhotoLibraryPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    private let onComplete: ([UIImage], Bool) -> Void

    init(
        onComplete: @escaping ([UIImage], Bool) -> Void,
    ) {
        self.onComplete = onComplete
    }

    func picker(
        _: PHPickerViewController,
        didFinishPicking results: [PHPickerResult],
    ) {
        loadSelection(
            providers: results.map(
                \.itemProvider,
            ),
        )
    }

    func loadSelection(
        providers candidates: [NSItemProvider],
    ) {
        let providers = candidates.filter {
            $0.canLoadObject(
                ofClass: UIImage.self,
            )
        }

        guard !providers.isEmpty else {
            onComplete(
                [],
                !candidates.isEmpty,
            )
            return
        }

        var images = [UIImage?](
            repeating: nil,
            count: providers.count,
        )
        let lock = NSLock()
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            group.enter()
            provider.loadObject(
                ofClass: UIImage.self,
            ) { object, _ in
                if let image = object as? UIImage {
                    lock.lock()
                    images[
                        index,
                    ] = image
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(
            queue: .main,
        ) { [onComplete] in
            let loadedImages = images.compactMap(
                \.self,
            )
            onComplete(
                loadedImages,
                loadedImages.count != candidates.count,
            )
        }
    }
}
