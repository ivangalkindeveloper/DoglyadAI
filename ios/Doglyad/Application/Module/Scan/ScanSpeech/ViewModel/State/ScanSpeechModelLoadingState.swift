import DoglyadSpeech

@MainActor
final class ScanSpeechModelLoadingState: ScanSpeechStateProtocol, @MainActor Equatable {
    let preparation: DSpeechModelPreparationStatus

    init(
        preparation: DSpeechModelPreparationStatus,
    ) {
        self.preparation = preparation
    }

    static func == (
        lhs: ScanSpeechModelLoadingState,
        rhs: ScanSpeechModelLoadingState,
    ) -> Bool {
        lhs.preparation == rhs.preparation
    }
}
