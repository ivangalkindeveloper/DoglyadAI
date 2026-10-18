import DoglyadSpeech

@MainActor
final class ScanSpeechTranscribingState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechTranscribingState,
        _: ScanSpeechTranscribingState,
    ) -> Bool {
        true
    }
}
