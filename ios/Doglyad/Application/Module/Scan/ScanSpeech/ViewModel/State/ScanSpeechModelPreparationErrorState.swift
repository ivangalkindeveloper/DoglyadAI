import DoglyadSpeech

@MainActor
final class ScanSpeechModelPreparationErrorState: ScanSpeechStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanSpeechModelPreparationErrorState,
        _: ScanSpeechModelPreparationErrorState,
    ) -> Bool {
        true
    }
}
