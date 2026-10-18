import Foundation

@MainActor
final class ScanSpeechAutomaticParsingState: ScanSpeechStateProtocol, ScanSpeechParsingStateProtocol, @MainActor Equatable {
    let parsedText: String

    init(
        parsedText: String,
    ) {
        self.parsedText = parsedText
    }

    static func == (
        lhs: ScanSpeechAutomaticParsingState,
        rhs: ScanSpeechAutomaticParsingState,
    ) -> Bool {
        lhs.parsedText == rhs.parsedText
    }
}
