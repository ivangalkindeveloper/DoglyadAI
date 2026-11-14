@MainActor
final class StorageInitialState: StorageStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: StorageInitialState,
        _: StorageInitialState,
    ) -> Bool {
        true
    }
}
