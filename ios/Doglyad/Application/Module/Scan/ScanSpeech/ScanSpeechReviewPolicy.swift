import DoglyadSpeech
import Foundation

enum ScanSpeechReviewPolicy {
    /// Returns the text as shown in the editor. Trimming is used only to decide
    /// whether the action is available; it must not alter the model input.
    static func textForParsing(
        transcript: DictationTranscript,
        visibleText: String
    ) -> String? {
        let trimmed = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch transcript.completion {
        case .finished:
            return visibleText
        case .timedOut, .interrupted, .failed:
            let original = transcript.correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == original ? nil : visibleText
        case .cancelled:
            return nil
        }
    }
}
