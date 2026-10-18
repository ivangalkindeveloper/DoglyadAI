@MainActor
final class StorageClearProtocolsState: StorageClearProtocolsStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageClearProtocolsState,
        _: StorageClearProtocolsState,
    ) -> Bool {
        true
    }
}
