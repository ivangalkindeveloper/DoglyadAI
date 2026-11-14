import Foundation

@MainActor
final class PhotoViewInitialState: PhotoViewStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: PhotoViewInitialState,
        _: PhotoViewInitialState,
    ) -> Bool {
        true
    }
}
