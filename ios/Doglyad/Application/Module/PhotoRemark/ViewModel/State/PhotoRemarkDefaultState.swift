@MainActor
final class PhotoRemarkDefaultState: PhotoRemarkStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoRemarkDefaultState,
        _: PhotoRemarkDefaultState,
    ) -> Bool {
        true
    }
}
