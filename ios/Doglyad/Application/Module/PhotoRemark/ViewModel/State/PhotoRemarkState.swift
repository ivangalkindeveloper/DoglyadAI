@MainActor
final class PhotoRemarkState: PhotoRemarkStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoRemarkState,
        _: PhotoRemarkState,
    ) -> Bool {
        true
    }
}
