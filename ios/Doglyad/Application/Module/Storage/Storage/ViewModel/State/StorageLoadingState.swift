@MainActor
final class StorageLoadingState: StorageStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageLoadingState,
        _: StorageLoadingState,
    ) -> Bool {
        true
    }
}
