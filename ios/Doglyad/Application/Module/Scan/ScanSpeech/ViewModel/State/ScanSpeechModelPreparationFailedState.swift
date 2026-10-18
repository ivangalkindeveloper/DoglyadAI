import DoglyadSpeech

@MainActor
final class ScanSpeechModelPreparationFailedState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechModelPreparationFailedState,
        _: ScanSpeechModelPreparationFailedState,
    ) -> Bool {
        true
    }
}
