import DoglyadNeuralModel
import DoglyadSpeech
import Foundation

enum ScanSpeechConfidencePolicy {
    // Measured on four synthetic audio sets on the physical iPhone. These are
    // conservative gates for structured values, not calibrated probabilities.
    private static let minimumQuoteConfidence = 0.7
    private static let minimumIdentifierConfidence = 0.85

    static func plan(
        proposal: DictationProposal,
        transcript: DictationTranscript,
        parsedText: String
    ) -> ScanSpeechReviewPlan {
        var automatic: [VoiceFieldProposal] = []
        var uncertain: [VoiceFieldProposal] = []
        for field in proposal.proposals {
            if canApplyAutomatically(field, proposal: proposal, transcript: transcript, parsedText: parsedText) {
                automatic.append(field)
            } else {
                uncertain.append(field)
            }
        }
        return ScanSpeechReviewPlan(automatic: automatic, uncertain: uncertain)
    }

    private static func canApplyAutomatically(
        _ field: VoiceFieldProposal,
        proposal: DictationProposal,
        transcript: DictationTranscript,
        parsedText: String
    ) -> Bool {
        guard transcript.isFinal, parsedText == transcript.correctedText,
              field.warnings.isEmpty else { return false }
        switch proposal.source {
        case .labeledDictation:
            break
        case .explicitFacts:
            return false
        case .localModel:
            return false
        case .serverModel:
            return false
        }
        let evidence: String
        let threshold: Double
        switch field.id {
        case .examinationNumber:
            guard case let .text(identifier) = field.value,
                  let range = uniqueRange(for: identifier, in: field.sourceQuote),
                  hasWordBoundaries(range, in: field.sourceQuote)
            else { return false }
            evidence = identifier
            threshold = minimumIdentifierConfidence
        case .patientGender, .patientWeightKG:
            evidence = field.sourceQuote
            threshold = minimumQuoteConfidence
        case .patientName, .patientDateOfBirth, .patientHeightCM, .patientComplaints, .examinationDescription:
            return false
        }
        guard uniqueRange(for: field.sourceQuote, in: transcript.rawText) != nil else { return false }
        guard let confidence = minimumConfidence(
            for: evidence,
            in: transcript.rawText,
            spans: transcript.confidenceSpans
        ) else { return false }
        return confidence >= threshold
    }

    static func minimumConfidence(
        for quote: String,
        in rawText: String,
        spans: [DSpeechConfidenceSpan]
    ) -> Double? {
        guard let first = uniqueRange(for: quote, in: rawText) else { return nil }
        let range = NSRange(first, in: rawText)
        let characters = Array(rawText.utf16)
        var minimum = 1.0
        var found = false
        for offset in range.location ..< NSMaxRange(range) {
            guard let scalar = UnicodeScalar(characters[offset]) else { return nil }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            let covering = spans.filter { span in
                span.utf16Start <= offset && offset < span.utf16Start + span.utf16Length
                    && span.confidence.isFinite && (0 ... 1).contains(span.confidence)
            }
            guard covering.count == 1 else { return nil }
            minimum = min(minimum, covering[0].confidence)
            found = true
        }
        return found ? minimum : nil
    }

    private static func uniqueRange(for literal: String, in text: String) -> Range<String.Index>? {
        guard !literal.isEmpty,
              let first = text.range(of: literal),
              text.range(of: literal, range: first.upperBound ..< text.endIndex) == nil
        else { return nil }
        return first
    }

    private static func hasWordBoundaries(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = text[..<range.lowerBound].last
        let after = text[range.upperBound...].first
        return (before.map { !$0.isLetter && !$0.isNumber } ?? true)
            && (after.map { !$0.isLetter && !$0.isNumber } ?? true)
    }
}
