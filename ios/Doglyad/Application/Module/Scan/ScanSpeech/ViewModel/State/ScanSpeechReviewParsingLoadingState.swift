import Foundation

@MainActor
final class ScanSpeechReviewParsingLoadingState: ScanSpeechStateProtocol, @MainActor Equatable {
    let parsedText: String

    init(
        parsedText: String,
    ) {
        self.parsedText = parsedText
    }

    static func == (
        lhs: ScanSpeechReviewParsingLoadingState,
        rhs: ScanSpeechReviewParsingLoadingState,
    ) -> Bool {
        lhs.parsedText == rhs.parsedText
    }
}
