import DoglyadSpeech

@MainActor
final class ScanSpeechModelPreparationErrorState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechModelPreparationErrorState,
        _: ScanSpeechModelPreparationErrorState,
    ) -> Bool {
        true
    }
}
