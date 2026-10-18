import Foundation

@MainActor
final class PhotoViewContentState: PhotoViewStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoViewContentState,
        _: PhotoViewContentState,
    ) -> Bool {
        true
    }
}
