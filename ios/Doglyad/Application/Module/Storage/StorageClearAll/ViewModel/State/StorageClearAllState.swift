@MainActor
final class StorageClearAllState: StorageClearAllStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageClearAllState,
        _: StorageClearAllState,
    ) -> Bool {
        true
    }
}
