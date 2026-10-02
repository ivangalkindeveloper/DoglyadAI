@testable import Doglyad
@testable import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import Testing

struct ScanSpeechConfidencePolicyTests {
    private let text = "номер исследования: 123; пол: мужчина; дата рождения: 28.03.1994; вес: 72 кг; жалобы: нет"

    @Test("Only literal structured fields with strong recognition evidence bypass review")
    func automaticFields() throws {
        let proposal = try parsed(text)
        let transcript = recording(text, confidence: 1)
        let plan = ScanSpeechConfidencePolicy.plan(proposal: proposal, transcript: transcript, parsedText: text)

        #expect(Set(plan.automatic.map(\.id)) == Set([
            .examinationNumber, .patientGender, .patientWeightKG,
        ]))
        #expect(plan.uncertain.contains { $0.id == .patientDateOfBirth })
        #expect(plan.uncertain.contains { $0.id == .patientComplaints })
    }

    @Test("Missing or weak confidence keeps every field for review")
    func weakRecognition() throws {
        let proposal = try parsed(text)
        for confidence in [0.69, nil] as [Double?] {
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: recording(text, confidence: confidence),
                parsedText: text
            )
            #expect(plan.automatic.isEmpty)
        }
    }

    @Test("A clear identifier can be filled when its label has low confidence")
    func identifierUsesValueEvidence() throws {
        let proposal = try parsed(text)
        let value = "123"
        let range = try #require(text.range(of: value))
        let start = NSRange(text.startIndex ..< range.lowerBound, in: text).length
        let valueLength = (value as NSString).length
        let totalLength = (text as NSString).length
        let transcript = DictationTranscript(
            rawText: text,
            correctedText: text,
            locale: Locale(identifier: "ru_RU"),
            engine: .speechAnalyzer,
            completion: .finished,
            confidenceSpans: [
                DSpeechConfidenceSpan(utf16Start: 0, utf16Length: start, confidence: 0.3),
                DSpeechConfidenceSpan(utf16Start: start, utf16Length: valueLength, confidence: 0.9),
                DSpeechConfidenceSpan(
                    utf16Start: start + valueLength,
                    utf16Length: totalLength - start - valueLength,
                    confidence: 0.3
                ),
            ]
        )
        let plan = ScanSpeechConfidencePolicy.plan(proposal: proposal, transcript: transcript, parsedText: text)
        #expect(plan.automatic.map(\.id) == [.examinationNumber])
    }

    @Test("A number embedded in another number is not identifier evidence")
    func identifierRequiresBoundaries() {
        let raw = "номер исследования: 123"
        let proposal = DictationProposal(
            source: .labeledDictation,
            proposals: [VoiceFieldProposal(
                id: .examinationNumber,
                value: .text("23"),
                sourceQuote: raw
            )],
            unmappedFindings: [],
            rejectedFieldIds: []
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(raw, confidence: 1),
            parsedText: raw
        )
        #expect(plan.automatic.isEmpty)
    }

    @Test("Model output and validation warnings always require review")
    func unverifiedProposal() throws {
        let labeled = try parsed(text)
        let model = DictationProposal(
            source: .localModel,
            proposals: labeled.proposals,
            unmappedFindings: [],
            rejectedFieldIds: []
        )
        let modelPlan = ScanSpeechConfidencePolicy.plan(
            proposal: model, transcript: recording(text, confidence: 1), parsedText: text
        )
        #expect(modelPlan.automatic.isEmpty)

        let first = try #require(labeled.proposals.first)
        let warned = DictationProposal(
            source: .labeledDictation,
            proposals: [VoiceFieldProposal(
                id: first.id, value: first.value, sourceQuote: first.sourceQuote,
                warnings: [.ambiguousDictation]
            )],
            unmappedFindings: [],
            rejectedFieldIds: []
        )
        let warnedPlan = ScanSpeechConfidencePolicy.plan(
            proposal: warned, transcript: recording(text, confidence: 1), parsedText: text
        )
        #expect(warnedPlan.automatic.isEmpty)
    }

    @Test("Editing, incomplete recording and lexicon changes disable automatic filling")
    func changedSource() throws {
        let proposal = try parsed(text)
        let edited = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(text, confidence: 1),
            parsedText: text + " исправлено"
        )
        #expect(edited.automatic.isEmpty)

        let incomplete = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(text, confidence: 1, completion: .timedOut),
            parsedText: text
        )
        #expect(incomplete.automatic.isEmpty)

        let changed = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(text.replacingOccurrences(of: "мужчина", with: "женщина"),
                                  correctedText: text, confidence: 1),
            parsedText: text
        )
        #expect(changed.automatic.allSatisfy { $0.id != .patientGender })
    }

    @Test("A quote must be unique and covered across its entire UTF-16 range")
    func quoteCoverage() {
        let quote = "пол: мужчина"
        let raw = "😀 пол: мужчина"
        let offset = ("😀 " as NSString).length
        let full = DSpeechConfidenceSpan(utf16Start: offset, utf16Length: (quote as NSString).length, confidence: 0.995)
        #expect(ScanSpeechConfidencePolicy.minimumConfidence(for: quote, in: raw, spans: [full]) == 0.995)
        let short = DSpeechConfidenceSpan(utf16Start: offset, utf16Length: 3, confidence: 1)
        #expect(ScanSpeechConfidencePolicy.minimumConfidence(for: quote, in: raw, spans: [short]) == nil)
        #expect(ScanSpeechConfidencePolicy.minimumConfidence(
            for: quote, in: "\(raw); \(quote)", spans: [full]
        ) == nil)
    }

    private func parsed(_ text: String) throws -> DictationProposal {
        try #require(DictationLabeledFormParser.parse(request: DictationParseRequest(
            text: text,
            examinationTypeId: "abdominalCavity",
            locale: Locale(identifier: "ru_RU"),
            allowedFields: VoiceFieldId.allCases
        )))
    }

    private func recording(
        _ rawText: String,
        correctedText: String? = nil,
        confidence: Double?,
        completion: DictationCompletion = .finished
    ) -> DictationTranscript {
        let spans = confidence.map {
            [DSpeechConfidenceSpan(utf16Start: 0, utf16Length: (rawText as NSString).length, confidence: $0)]
        } ?? []
        return DictationTranscript(
            rawText: rawText,
            correctedText: correctedText ?? rawText,
            locale: Locale(identifier: "ru_RU"),
            engine: .speechAnalyzer,
            completion: completion,
            confidenceSpans: spans
        )
    }
}
