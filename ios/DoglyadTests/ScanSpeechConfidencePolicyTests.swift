@testable import Doglyad
@testable import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import Testing

struct ScanSpeechConfidencePolicyTests {
    @Test(
        "Repeat stability cannot certify medical prose, while clear scalar fields still apply",
    )
    func medicalProseNeedsReview() {
        let raw = "Жалобы: Боль в колене. Спокой боли нет. Пол мужчина."
        let transcript = DSpeechTranscript(
            rawText: raw,
            correctedText: raw,
            locale: Locale(
                identifier: "ru",
            ),
            engine: .whisperKit,
            completion: .finished,
            decodingSpans: [.init(
                utf16Start: 0,
                utf16Length: (raw as NSString).length,
                averageLogProbability: -0.01,
                temperature: 0,
                compressionRatio: 1.2,
                recheckedText: raw,
            )],
        )
        let proposal = DNeuralUltrasoundDictationProposal(
            source: .serverModel,
            proposals: [
                .init(
                    id: .patientComplaints,
                    value: .text(
                        "Боль в колене. Спокой боли нет.",
                    ),
                    sourceQuote: "Жалобы: Боль в колене. Спокой боли нет.",
                ),
                .init(
                    id: .patientGender,
                    value: .gender(
                        .male,
                    ),
                    sourceQuote: "Пол мужчина.",
                ),
            ],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript.locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            plan.automatic.map(
                \.id,
            ) == [.patientGender],
        )
        #expect(
            plan.uncertain.map(
                \.id,
            ) == [.patientComplaints],
        )
    }

    @Test(
        "Whisper requires complete stable decoder evidence and keeps proper names for review",
    )
    func whisperEvidence() throws {
        let raw = "Patient: Nathan Cole. Weight: 81.3 kg. Gender male."
        let proposal = DNeuralUltrasoundDictationProposal(
            source: .localModel,
            proposals: [
                DNeuralUltrasoundVoiceFieldProposal(
                    id: .patientName,
                    value: .text(
                        "Nathan Cole",
                    ),
                    sourceQuote: "Patient: Nathan Cole.",
                ),
                DNeuralUltrasoundVoiceFieldProposal(
                    id: .patientWeightKG,
                    value: .number(
                        81.3,
                    ),
                    sourceQuote: "Weight: 81.3 kg.",
                ),
                DNeuralUltrasoundVoiceFieldProposal(
                    id: .patientGender,
                    value: .gender(
                        .male,
                    ),
                    sourceQuote: "male",
                ),
            ],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        func transcript(
            score: Double,
            repeated: String?,
        ) -> DSpeechTranscript {
            DSpeechTranscript(
                rawText: raw,
                correctedText: raw,
                locale: Locale(
                    identifier: "en",
                ),
                engine: .whisperKit,
                completion: .finished,
                decodingSpans: [DSpeechDecodingSpan(
                    utf16Start: 0,
                    utf16Length: (raw as NSString).length,
                    averageLogProbability: score,
                    temperature: 0,
                    compressionRatio: 1.2,
                    recheckedText: repeated,
                )],
            )
        }
        let strong = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript(
                score: -0.2,
                repeated: raw,
            ),
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript(
                    score: -0.2,
                    repeated: raw,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            strong.automatic.map(
                \.id,
            ) == [.patientWeightKG, .patientGender],
        )
        #expect(
            strong.uncertain.map(
                \.id,
            ) == [.patientName],
        )
        let weak = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript(
                score: -0.31,
                repeated: raw,
            ),
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript(
                    score: -0.31,
                    repeated: raw,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            weak.automatic.isEmpty,
        )
        let missing = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript(
                score: -0.2,
                repeated: nil,
            ),
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript(
                    score: -0.2,
                    repeated: nil,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            missing.automatic.isEmpty,
        )
        let changed = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript(
                score: -0.2,
                repeated: raw.replacingOccurrences(
                    of: "male",
                    with: "female",
                ),
            ),
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript(
                    score: -0.2,
                    repeated: raw.replacingOccurrences(
                        of: "male",
                        with: "female",
                    ),
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            changed.automatic.map(
                \.id,
            ) == [.patientWeightKG],
        )
    }

    private let text = "номер исследования: 123; пол: мужчина; дата рождения: 28.03.1994; вес: 72 кг; жалобы: нет"

    @Test(
        "Only literal structured fields with strong recognition evidence bypass review",
    )
    func automaticFields() throws {
        let proposal = try parsed(
            text,
        )
        let transcript = recording(
            text,
            confidence: 1,
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript.locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )

        #expect(
            Set(
                plan.automatic.map(
                    \.id,
                ),
            ) == Set(
                [
                    .examinationNumber,
                    .patientGender,
                    .patientWeightKG,
                ],
            ),
        )
        #expect(
            plan.uncertain.contains { $0.id == .patientDateOfBirth },
        )
        #expect(
            plan.uncertain.contains { $0.id == .patientComplaints },
        )
    }

    @Test(
        "Missing or weak confidence keeps every field for review",
    )
    func weakRecognition() throws {
        let proposal = try parsed(
            text,
        )
        for confidence in [0.69, nil] as [Double?] {
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: recording(
                    text,
                    confidence: confidence,
                ),
                parsedText: text,
                noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                    locale: recording(
                        text,
                        confidence: confidence,
                    ).locale,
                ).pattern(
                    .noComplaintsValue,
                ),
            )
            #expect(
                plan.automatic.isEmpty,
            )
        }
    }

    @Test(
        "A clear identifier can be filled when its label has low confidence",
    )
    func identifierUsesValueEvidence() throws {
        let proposal = try parsed(
            text,
        )
        let value = "123"
        let range = try #require(
            text.range(
                of: value,
            ),
        )
        let start = NSRange(
            text.startIndex ..< range.lowerBound,
            in: text,
        ).length
        let valueLength = (value as NSString).length
        let totalLength = (text as NSString).length
        let transcript = DSpeechTranscript(
            rawText: text,
            correctedText: text,
            locale: Locale(
                identifier: "ru_RU",
            ),
            engine: .speechAnalyzer,
            completion: .finished,
            confidenceSpans: [
                DSpeechConfidenceSpan(
                    utf16Start: 0,
                    utf16Length: start,
                    confidence: 0.3,
                ),
                DSpeechConfidenceSpan(
                    utf16Start: start,
                    utf16Length: valueLength,
                    confidence: 0.9,
                ),
                DSpeechConfidenceSpan(
                    utf16Start: start + valueLength,
                    utf16Length: totalLength - start - valueLength,
                    confidence: 0.3,
                ),
            ],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: transcript,
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: transcript.locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            plan.automatic.map(
                \.id,
            ) == [.examinationNumber],
        )
    }

    @Test(
        "A number embedded in another number is not identifier evidence",
    )
    func identifierRequiresBoundaries() {
        let raw = "номер исследования: 123"
        let proposal = DNeuralUltrasoundDictationProposal(
            source: .labeledDictation,
            proposals: [DNeuralUltrasoundVoiceFieldProposal(
                id: .examinationNumber,
                value: .text(
                    "23",
                ),
                sourceQuote: raw,
            )],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(
                raw,
                confidence: 1,
            ),
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    raw,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            plan.automatic.isEmpty,
        )
    }

    @Test(
        "Model output and validation warnings always require review",
    )
    func unverifiedProposal() throws {
        let labeled = try parsed(
            text,
        )
        let model = DNeuralUltrasoundDictationProposal(
            source: .localModel,
            proposals: labeled.proposals,
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let modelPlan = ScanSpeechConfidencePolicy.plan(
            proposal: model,
            transcript: recording(
                text,
                confidence: 1,
            ),
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    text,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            modelPlan.automatic.isEmpty,
        )

        let first = try #require(
            labeled.proposals.first,
        )
        let warned = DNeuralUltrasoundDictationProposal(
            source: .labeledDictation,
            proposals: [DNeuralUltrasoundVoiceFieldProposal(
                id: first.id,
                value: first.value,
                sourceQuote: first.sourceQuote,
                warnings: [.ambiguousDictation],
            )],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let warnedPlan = ScanSpeechConfidencePolicy.plan(
            proposal: warned,
            transcript: recording(
                text,
                confidence: 1,
            ),
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    text,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            warnedPlan.automatic.isEmpty,
        )
    }

    @Test(
        "A questionable field always requires review even with strong speech evidence",
    )
    func questionableAccuracyRequiresReview() {
        let raw = "номер исследования: 123"
        let proposal = DNeuralUltrasoundDictationProposal(
            source: .labeledDictation,
            proposals: [DNeuralUltrasoundVoiceFieldProposal(
                id: .examinationNumber,
                value: .text(
                    "123",
                ),
                sourceQuote: raw,
                accuracy: .questionable,
            )],
            unmappedFindings: [],
            rejectedFieldIds: [],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(
                raw,
                confidence: 1,
            ),
            parsedText: raw,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    raw,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            plan.automatic.isEmpty,
        )
        #expect(
            plan.uncertain.map(
                \.id,
            ) == [.examinationNumber],
        )
    }

    @Test(
        "A mixed proposal retains automatic eligibility only for its labeled fields",
    )
    func mixedFieldSources() throws {
        let labeled = try parsed(
            text,
        )
        let mixed = DNeuralUltrasoundDictationProposal(
            source: .localModel,
            proposals: labeled.proposals,
            unmappedFindings: [],
            rejectedFieldIds: [],
            fieldSources: [
                .examinationNumber: .labeledDictation,
                .patientGender: .localModel,
                .patientWeightKG: .explicitFacts,
            ],
        )
        let plan = ScanSpeechConfidencePolicy.plan(
            proposal: mixed,
            transcript: recording(
                text,
                confidence: 1,
            ),
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    text,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            plan.automatic.map(
                \.id,
            ) == [.examinationNumber],
        )
        #expect(
            plan.uncertain.contains { $0.id == .patientGender },
        )
        #expect(
            plan.uncertain.contains { $0.id == .patientWeightKG },
        )
    }

    @Test(
        "Editing, incomplete recording and lexicon changes disable automatic filling",
    )
    func changedSource() throws {
        let proposal = try parsed(
            text,
        )
        let edited = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(
                text,
                confidence: 1,
            ),
            parsedText: text + " исправлено",
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    text,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            edited.automatic.isEmpty,
        )

        let incomplete = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(
                text,
                confidence: 1,
                completion: .timedOut,
            ),
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    text,
                    confidence: 1,
                    completion: .timedOut,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            incomplete.automatic.isEmpty,
        )

        let changed = ScanSpeechConfidencePolicy.plan(
            proposal: proposal,
            transcript: recording(
                text.replacingOccurrences(
                    of: "мужчина",
                    with: "женщина",
                ),
                correctedText: text,
                confidence: 1,
            ),
            parsedText: text,
            noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                locale: recording(
                    text.replacingOccurrences(
                        of: "мужчина",
                        with: "женщина",
                    ),
                    correctedText: text,
                    confidence: 1,
                ).locale,
            ).pattern(
                .noComplaintsValue,
            ),
        )
        #expect(
            changed.automatic.allSatisfy { $0.id != .patientGender },
        )
    }

    @Test(
        "A quote must be unique and covered across its entire UTF-16 range",
    )
    func quoteCoverage() {
        let quote = "пол: мужчина"
        let raw = "😀 пол: мужчина"
        let offset = ("😀 " as NSString).length
        let full = DSpeechConfidenceSpan(
            utf16Start: offset,
            utf16Length: (quote as NSString).length,
            confidence: 0.995,
        )
        #expect(
            ScanSpeechConfidencePolicy.minimumConfidence(
                for: quote,
                in: raw,
                spans: [full],
            ) == 0.995,
        )
        let short = DSpeechConfidenceSpan(
            utf16Start: offset,
            utf16Length: 3,
            confidence: 1,
        )
        #expect(
            ScanSpeechConfidencePolicy.minimumConfidence(
                for: quote,
                in: raw,
                spans: [short],
            ) == nil,
        )
        #expect(
            ScanSpeechConfidencePolicy.minimumConfidence(
                for: quote,
                in: "\(raw); \(quote)",
                spans: [full],
            ) == nil,
        )
    }

    private func parsed(
        _ text: String,
    ) throws -> DNeuralUltrasoundDictationProposal {
        try #require(
            DNeuralUltrasoundDictationLabeledFormParser.parse(
                request: DNeuralUltrasoundDictationParseRequest(
                    text: text,
                    examinationTypeId: "abdominalCavity",
                    examinationTypeTitle: "Unit-test examination",
                    locale: Locale(
                        identifier: "ru_RU",
                    ),
                    allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                    localization: VoiceLocalizationTestSupport.dictation(
                        locale: Locale(
                            identifier: "ru_RU",
                        ),
                    ),
                ),
            ),
        )
    }

    private func recording(
        _ rawText: String,
        correctedText: String? = nil,
        confidence: Double?,
        completion: DSpeechCompletion = .finished,
    ) -> DSpeechTranscript {
        let spans = confidence.map {
            [DSpeechConfidenceSpan(
                utf16Start: 0,
                utf16Length: (rawText as NSString).length,
                confidence: $0,
            )]
        } ?? []
        return DSpeechTranscript(
            rawText: rawText,
            correctedText: correctedText ?? rawText,
            locale: Locale(
                identifier: "ru_RU",
            ),
            engine: .speechAnalyzer,
            completion: completion,
            confidenceSpans: spans,
        )
    }
}
