import Foundation

/// A result of one recording session. Partial text remains available for review,
/// but only a finished result can be sent directly to the form parser.
public struct DictationTranscript: Sendable {
    public let rawText: String
    public let correctedText: String
    public let locale: Locale
    public let engine: DictationEngine
    public let completion: DictationCompletion
    public let confidenceSpans: [DSpeechConfidenceSpan]

    public var isFinal: Bool {
        switch completion {
        case .finished:
            return true
        case .timedOut, .interrupted, .cancelled, .failed:
            return false
        }
    }

    public var isReadyForParsing: Bool {
        isFinal && !correctedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        rawText: String,
        correctedText: String,
        locale: Locale,
        engine: DictationEngine,
        completion: DictationCompletion,
        confidenceSpans: [DSpeechConfidenceSpan] = []
    ) {
        self.rawText = rawText
        self.correctedText = correctedText
        self.locale = locale
        self.engine = engine
        self.completion = completion
        self.confidenceSpans = confidenceSpans
    }
}
