import Foundation

@MainActor
final class PhotoViewEmptyState: PhotoViewStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoViewEmptyState,
        _: PhotoViewEmptyState,
    ) -> Bool {
        true
    }
}
