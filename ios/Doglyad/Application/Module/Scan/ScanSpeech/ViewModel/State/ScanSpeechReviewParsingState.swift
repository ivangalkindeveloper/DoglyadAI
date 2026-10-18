import Foundation

@MainActor
final class ScanSpeechReviewParsingState: ScanSpeechStateProtocol, ScanSpeechParsingStateProtocol, @MainActor Equatable {
    let parsedText: String

    init(
        parsedText: String,
    ) {
        self.parsedText = parsedText
    }

    static func == (
        lhs: ScanSpeechReviewParsingState,
        rhs: ScanSpeechReviewParsingState,
    ) -> Bool {
        lhs.parsedText == rhs.parsedText
    }
}
