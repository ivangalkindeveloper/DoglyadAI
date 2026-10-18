import DoglyadSpeech

@MainActor
final class ScanSpeechPreparingModelState: ScanSpeechStateProtocol, @MainActor Equatable {
    let preparation: DSpeechModelPreparationStatus

    init(
        preparation: DSpeechModelPreparationStatus,
    ) {
        self.preparation = preparation
    }

    static func == (
        lhs: ScanSpeechPreparingModelState,
        rhs: ScanSpeechPreparingModelState,
    ) -> Bool {
        lhs.preparation == rhs.preparation
    }
}
