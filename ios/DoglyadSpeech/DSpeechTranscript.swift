import Foundation

/// A recording result. Usable partial speech can be parsed; field evidence
/// determines which values require review. Cancelled recordings cannot be applied.
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
        switch completion {
        case .cancelled:
            false
        case .finished, .timedOut, .interrupted, .failed:
            !correctedText.trimmingCharacters(
                in: .whitespacesAndNewlines,
            ).isEmpty
        }
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
