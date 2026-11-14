@MainActor
final class PhotoRemarkDefaultState: PhotoRemarkStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: PhotoRemarkDefaultState,
        _: PhotoRemarkDefaultState,
    ) -> Bool {
        true
    }
}
