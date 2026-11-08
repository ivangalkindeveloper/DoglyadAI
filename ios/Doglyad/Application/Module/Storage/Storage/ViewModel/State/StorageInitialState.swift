@MainActor
final class StorageInitialState: StorageStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageInitialState,
        _: StorageInitialState,
    ) -> Bool {
        true
    }
}
