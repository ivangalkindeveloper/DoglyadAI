@MainActor
final class StorageClearProtocolsDefaultState: StorageClearProtocolsStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: StorageClearProtocolsDefaultState,
        _: StorageClearProtocolsDefaultState,
    ) -> Bool {
        true
    }
}
