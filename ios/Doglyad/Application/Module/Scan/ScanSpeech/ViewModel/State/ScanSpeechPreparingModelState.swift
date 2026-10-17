import DoglyadSpeech

@MainActor
final class ScanSpeechPreparingModelState: ScanSpeechStateProtocol {
    let preparation: DSpeechModelPreparation

    init(
        preparation: DSpeechModelPreparation,
    ) {
        self.preparation = preparation
    }
}
