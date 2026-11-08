import DoglyadSpeech

@MainActor
final class ScanSpeechRecordingPreparationLoadingState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechRecordingPreparationLoadingState,
        _: ScanSpeechRecordingPreparationLoadingState,
    ) -> Bool {
        true
    }
}
