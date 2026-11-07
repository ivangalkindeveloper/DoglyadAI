import Foundation

@MainActor
final class PhotoViewState: PhotoViewStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoViewState,
        _: PhotoViewState,
    ) -> Bool {
        true
    }
}
