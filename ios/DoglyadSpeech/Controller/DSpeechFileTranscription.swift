import Foundation

public struct DSpeechFileTranscription {
    public let rawText: String
    public let correctedText: String
    public let confidenceSpans: [DSpeechConfidenceSpan]

    public init(
        rawText: String,
        correctedText: String,
        confidenceSpans: [DSpeechConfidenceSpan] = [],
    ) {
        self.rawText = rawText
        self.correctedText = correctedText
        self.confidenceSpans = confidenceSpans
    }
}
