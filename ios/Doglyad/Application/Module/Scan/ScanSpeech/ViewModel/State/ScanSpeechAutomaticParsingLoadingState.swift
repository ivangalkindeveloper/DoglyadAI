import Foundation

@MainActor
final class ScanSpeechAutomaticParsingLoadingState: ScanSpeechStateProtocol, ScanSpeechParsingStateProtocol, @MainActor Equatable {
    let parsedText: String

    init(
        parsedText: String,
    ) {
        self.parsedText = parsedText
    }

    static func == (
        lhs: ScanSpeechAutomaticParsingLoadingState,
        rhs: ScanSpeechAutomaticParsingLoadingState,
    ) -> Bool {
        lhs.parsedText == rhs.parsedText
    }
}
