import Foundation
import Speech

/// Recognition confidence for a UTF-16 range in the uncorrected transcript.
public struct DSpeechConfidenceSpan: Sendable {
    public let utf16Start: Int
    public let utf16Length: Int
    public let confidence: Double

    public init(utf16Start: Int, utf16Length: Int, confidence: Double) {
        self.utf16Start = utf16Start
        self.utf16Length = utf16Length
        self.confidence = confidence
    }

    @available(iOS 26.0, *)
    public static func from(_ transcription: AttributedString) -> [Self] {
        var spans: [Self] = []
        var utf16Offset = 0
        for run in transcription.runs {
            let length = (String(transcription[run.range].characters) as NSString).length
            if let confidence = run.transcriptionConfidence, confidence.isFinite, length > 0 {
                spans.append(Self(
                    utf16Start: utf16Offset,
                    utf16Length: length,
                    confidence: confidence
                ))
            }
            utf16Offset += length
        }
        return spans
    }
}
