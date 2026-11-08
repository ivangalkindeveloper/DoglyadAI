@MainActor
final class StorageClearAllDefaultState: StorageClearAllStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageClearAllDefaultState,
        _: StorageClearAllDefaultState,
    ) -> Bool {
        true
    }
}
