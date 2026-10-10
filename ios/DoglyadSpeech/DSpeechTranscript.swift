import Foundation

/// A result of one recording session. Partial text remains available for review,
/// but only a finished result can be sent directly to the form parser.
public struct DSpeechTranscript: Sendable {
    public let rawText: String
    public let correctedText: String
    public let locale: Locale
    public let engine: DSpeechEngine
    public let completion: DSpeechCompletion
    public let confidenceSpans: [DSpeechConfidenceSpan]
    public let decodingSpans: [DSpeechDecodingSpan]

    public var isFinal: Bool {
        switch completion {
        case .finished:
            true
        case .timedOut, .interrupted, .cancelled, .failed:
            false
        }
    }

    public var isReadyForParsing: Bool {
        isFinal && !correctedText.trimmingCharacters(
            in: .whitespacesAndNewlines,
        ).isEmpty
    }

    public init(
        rawText: String,
        correctedText: String,
        locale: Locale,
        engine: DSpeechEngine,
        completion: DSpeechCompletion,
        confidenceSpans: [DSpeechConfidenceSpan] = [],
        decodingSpans: [DSpeechDecodingSpan] = [],
    ) {
        self.rawText = rawText
        self.correctedText = correctedText
        self.locale = locale
        self.engine = engine
        self.completion = completion
        self.confidenceSpans = confidenceSpans
        self.decodingSpans = decodingSpans
    }
}
