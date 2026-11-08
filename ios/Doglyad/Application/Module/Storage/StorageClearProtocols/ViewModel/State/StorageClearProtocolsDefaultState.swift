@MainActor
final class StorageClearProtocolsDefaultState: StorageClearProtocolsStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageClearProtocolsDefaultState,
        _: StorageClearProtocolsDefaultState,
    ) -> Bool {
        true
    }
}
