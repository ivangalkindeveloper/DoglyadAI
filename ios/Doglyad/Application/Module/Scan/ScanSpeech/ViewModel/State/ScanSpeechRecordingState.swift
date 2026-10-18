import DoglyadSpeech

@MainActor
final class ScanSpeechRecordingState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechRecordingState,
        _: ScanSpeechRecordingState,
    ) -> Bool {
        true
    }
}
