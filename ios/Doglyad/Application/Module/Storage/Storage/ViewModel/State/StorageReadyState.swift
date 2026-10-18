@MainActor
final class StorageReadyState: StorageStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageReadyState,
        _: StorageReadyState,
    ) -> Bool {
        true
    }
}
