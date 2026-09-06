import Router
import UIKit

final class PhotoLibraryPickerArguments: RouteArgumentsProtocol {
    let selectionLimit: Int
    let onComplete: ([UIImage]) -> Void

    init(
        selectionLimit: Int,
        onComplete: @escaping ([UIImage]) -> Void
    ) {
        self.selectionLimit = selectionLimit
        self.onComplete = onComplete
    }
}
