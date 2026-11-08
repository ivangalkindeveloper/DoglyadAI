import Foundation

@MainActor
final class PhotoViewInitialState: PhotoViewStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoViewInitialState,
        _: PhotoViewInitialState,
    ) -> Bool {
        true
    }
}
