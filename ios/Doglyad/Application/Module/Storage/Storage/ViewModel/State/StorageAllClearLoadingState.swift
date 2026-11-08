@MainActor
final class StorageAllClearLoadingState: StorageStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageAllClearLoadingState,
        _: StorageAllClearLoadingState,
    ) -> Bool {
        true
    }
}
