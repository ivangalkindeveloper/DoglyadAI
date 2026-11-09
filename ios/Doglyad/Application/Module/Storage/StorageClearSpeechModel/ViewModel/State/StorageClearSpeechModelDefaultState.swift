@MainActor
final class StorageClearSpeechModelDefaultState: StorageClearSpeechModelStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageClearSpeechModelDefaultState,
        _: StorageClearSpeechModelDefaultState,
    ) -> Bool {
        true
    }
}
