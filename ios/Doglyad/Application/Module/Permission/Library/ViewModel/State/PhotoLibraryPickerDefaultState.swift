@MainActor
final class PhotoLibraryPickerDefaultState: PhotoLibraryPickerStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: PhotoLibraryPickerDefaultState,
        _: PhotoLibraryPickerDefaultState,
    ) -> Bool {
        true
    }
}
