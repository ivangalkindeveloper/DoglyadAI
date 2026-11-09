import DoglyadSpeech

@MainActor
final class ScanSpeechTranscriptionLoadingState: ScanSpeechStateProtocol, @MainActor Equatable {
    let parsedText: String?

    init(
        parsedText: String? = nil,
    ) {
        self.parsedText = parsedText
    }

    static func == (
        lhs: ScanSpeechTranscriptionLoadingState,
        rhs: ScanSpeechTranscriptionLoadingState,
    ) -> Bool {
        lhs.parsedText == rhs.parsedText
    }
}
