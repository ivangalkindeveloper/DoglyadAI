@MainActor
final class PhotoLibraryPickerDefaultState: PhotoLibraryPickerStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoLibraryPickerDefaultState,
        _: PhotoLibraryPickerDefaultState,
    ) -> Bool {
        true
    }
}
