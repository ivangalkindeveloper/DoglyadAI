@MainActor
final class StorageProtocolsClearLoadingState: StorageStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageProtocolsClearLoadingState,
        _: StorageProtocolsClearLoadingState,
    ) -> Bool {
        true
    }
}
