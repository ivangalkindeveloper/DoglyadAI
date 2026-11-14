import Foundation

@MainActor
final class ScanSpeechReviewTranscriptState: ScanSpeechStateProtocol, @MainActor Equatable {
    init() {}

    static func == (
        _: ScanSpeechReviewTranscriptState,
        _: ScanSpeechReviewTranscriptState,
    ) -> Bool {
        true
    }
}
