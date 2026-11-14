@MainActor
final class StorageClearAllDefaultState: StorageClearAllStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: StorageClearAllDefaultState,
        _: StorageClearAllDefaultState,
    ) -> Bool {
        true
    }
}
