import DoglyadSpeech

@MainActor
final class ScanSpeechRecordingPreparationLoadingState: ScanSpeechStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanSpeechRecordingPreparationLoadingState,
        _: ScanSpeechRecordingPreparationLoadingState,
    ) -> Bool {
        true
    }
}
