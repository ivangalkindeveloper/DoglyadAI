import DoglyadSpeech

@MainActor
final class ScanSpeechRecordingState: ScanSpeechStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanSpeechRecordingState,
        _: ScanSpeechRecordingState,
    ) -> Bool {
        true
    }
}
