import DoglyadSpeech

@MainActor
final class ScanSpeechPreparingRecordingState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechPreparingRecordingState,
        _: ScanSpeechPreparingRecordingState,
    ) -> Bool {
        true
    }
}
