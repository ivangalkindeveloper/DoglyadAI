import Foundation

@MainActor
final class ScanSpeechAutomaticParsingState: ScanSpeechStateProtocol, ScanSpeechParsingStateProtocol {
    let parsedText: String

    init(
        parsedText: String,
    ) {
        self.parsedText = parsedText
    }
}
