import Foundation

@MainActor
final class ScanSpeechReviewParsingState: ScanSpeechStateProtocol, ScanSpeechParsingStateProtocol {
    let parsedText: String

    init(
        parsedText: String,
    ) {
        self.parsedText = parsedText
    }
}
