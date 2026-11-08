import DoglyadSpeech

@MainActor
final class ScanSpeechTranscriptionLoadingState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechTranscriptionLoadingState,
        _: ScanSpeechTranscriptionLoadingState,
    ) -> Bool {
        true
    }
}
