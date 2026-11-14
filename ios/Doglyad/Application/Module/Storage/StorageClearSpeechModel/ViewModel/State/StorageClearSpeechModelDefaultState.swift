@MainActor
final class StorageClearSpeechModelDefaultState: StorageClearSpeechModelStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: StorageClearSpeechModelDefaultState,
        _: StorageClearSpeechModelDefaultState,
    ) -> Bool {
        true
    }
}
