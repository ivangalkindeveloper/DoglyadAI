@MainActor
final class ScanSpeechTranscriptionErrorState: ScanSpeechStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanSpeechTranscriptionErrorState,
        _: ScanSpeechTranscriptionErrorState,
    ) -> Bool {
        true
    }
}
