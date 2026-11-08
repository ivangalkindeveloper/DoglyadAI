@MainActor
final class StorageSpeechModelDeleteLoadingState: StorageStateProtocol, @MainActor Equatable {
    static func == (
        _: StorageSpeechModelDeleteLoadingState,
        _: StorageSpeechModelDeleteLoadingState,
    ) -> Bool {
        true
    }
}
