@MainActor
final class PhotoLibraryPickerState: PhotoLibraryPickerStateProtocol, @MainActor Equatable {
    static func == (
        _: PhotoLibraryPickerState,
        _: PhotoLibraryPickerState,
    ) -> Bool {
        true
    }
}
