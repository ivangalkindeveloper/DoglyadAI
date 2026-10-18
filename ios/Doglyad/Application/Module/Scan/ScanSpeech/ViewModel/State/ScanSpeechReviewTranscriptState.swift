import Foundation

@MainActor
final class ScanSpeechReviewTranscriptState: ScanSpeechStateProtocol, @MainActor Equatable {
    static func == (
        _: ScanSpeechReviewTranscriptState,
        _: ScanSpeechReviewTranscriptState,
    ) -> Bool {
        true
    }
}
