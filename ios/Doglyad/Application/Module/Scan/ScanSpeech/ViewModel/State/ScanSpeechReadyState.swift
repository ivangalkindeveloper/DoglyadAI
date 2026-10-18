import DoglyadSpeech

@MainActor
final class ScanSpeechReadyState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechReadyState,
        _: ScanSpeechReadyState,
    ) -> Bool {
        true
    }
}
