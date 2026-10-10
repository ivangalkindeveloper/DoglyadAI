@testable import Doglyad
@testable import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import FoundationModels
import Testing

struct VoiceLocalizationTests {
    @Test(
        "Bundled catalogs are complete and selected explicitly, including regional locales",
        arguments: ["en", "en_US", "ru", "ru_RU"],
    )
    func selectedCatalog(
        code: String,
    ) throws {
        let locale = Locale(
            identifier: code,
        )
        let catalog = try VoiceLocalization.load(
            locale: locale,
        )
        #expect(
            catalog.code == locale.language.languageCode?.identifier,
        )
        #expect(
            catalog.dictation.numbers.ones.count == 20,
        )
        #expect(
            catalog.dictation.numbers.tens.count == 10,
        )
        for key in DNeuralUltrasoundDictationLocalizationKey.allCases {
            _ = try NSRegularExpression(
                pattern: catalog.dictation.pattern(
                    key,
                ),
            )
        }
    }

    @Test(
        "An unavailable language does not silently use another catalog",
    )
    func missingLanguage() {
        #expect(
            throws: VoiceLocalizationError.self,
        ) {
            try VoiceLocalization.load(
                locale: Locale(
                    identifier: "fr",
                ),
            )
        }
    }

    @Test(
        "Missing and unknown matching-rule keys fail catalog decoding",
        arguments: [false, true],
    )
    func detectsKeyDrift(
        extraKey: Bool,
    ) throws {
        var catalog = try catalogJSON(
            code: "en",
        )
        var dictation = try #require(
            catalog[
                "dictation",
            ] as? [String: Any],
        )
        var patterns = try #require(
            dictation[
                "patterns",
            ] as? [String: String],
        )
        if extraKey {
            patterns[
                "unregisteredRule",
            ] = "^test$"
        } else {
            patterns.removeValue(
                forKey: DNeuralUltrasoundDictationLocalizationKey.noComplaintsValue.rawValue,
            )
        }
        dictation[
            "patterns",
        ] = patterns
        catalog[
            "dictation",
        ] = dictation
        let data = try JSONSerialization.data(
            withJSONObject: catalog,
        )
        #expect(
            throws: DecodingError.self,
        ) {
            try JSONDecoder().decode(
                VoiceLocalization.self,
                from: data,
            )
        }
    }

    @Test(
        "Invalid matching expressions are rejected before recording starts",
    )
    func detectsInvalidExpression() throws {
        var catalog = try catalogJSON(
            code: "ru",
        )
        var dictation = try #require(
            catalog[
                "dictation",
            ] as? [String: Any],
        )
        var patterns = try #require(
            dictation[
                "patterns",
            ] as? [String: String],
        )
        patterns[
            DNeuralUltrasoundDictationLocalizationKey.patientNameLabel.rawValue,
        ] = "("
        dictation[
            "patterns",
        ] = patterns
        catalog[
            "dictation",
        ] = dictation
        let data = try JSONSerialization.data(
            withJSONObject: catalog,
        )
        #expect(
            throws: (any Error).self,
        ) {
            try JSONDecoder().decode(
                VoiceLocalization.self,
                from: data,
            )
        }
    }

    @Test(
        "Field labels, genders and spoken numbers use only the selected language",
    )
    func languagesAreIsolated() throws {
        let en = try VoiceLocalization.load(
            locale: Locale(
                identifier: "en",
            ),
        ).dictation
        let ru = try VoiceLocalization.load(
            locale: Locale(
                identifier: "ru",
            ),
        ).dictation
        #expect(
            DNeuralVoiceGender.fromSpokenWord(
                "мужчина",
                localization: en,
            ) == nil,
        )
        #expect(
            DNeuralVoiceGender.fromSpokenWord(
                "male",
                localization: ru,
            ) == nil,
        )
        #expect(
            DNeuralVoiceGender.fromSpokenWord(
                "male",
                localization: en,
            ) == .male,
        )
        #expect(
            DNeuralVoiceGender.fromSpokenWord(
                "мужчина",
                localization: ru,
            ) == .male,
        )
        #expect(
            DNeuralSpokenDigitSequence.parse(
                "ноль один",
                locale: Locale(
                    identifier: "en",
                ),
                localization: en.numbers,
            ) == nil,
        )
        #expect(
            DNeuralSpokenDigitSequence.parse(
                "zero one",
                locale: Locale(
                    identifier: "ru",
                ),
                localization: ru.numbers,
            ) == nil,
        )
        for (text, locale, localization) in [
            ("Пациент: Анна Иванова; вес: 68 кг", Locale(
                identifier: "en",
            ), en),
            ("Patient: Anna Smith; weight: 68 kg", Locale(
                identifier: "ru",
            ), ru),
        ] {
            let request = DNeuralUltrasoundDictationParseRequest(
                text: text,
                examinationTypeId: "abdominalCavity",
                examinationTypeTitle: "Unit-test examination",
                locale: locale,
                allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                localization: localization,
            )
            #expect(
                DNeuralUltrasoundDictationLabeledFormParser.parse(
                    request: request,
                ) == nil,
            )
            #expect(
                DNeuralUltrasoundDictationExplicitFactsExtractor.extract(
                    request: request,
                ).isEmpty,
            )
        }
    }

    @Test(
        "Absence of complaints can bypass review only in the selected language",
        arguments: ["en", "ru"],
    )
    func localizedConfidenceRule(
        code: String,
    ) throws {
        let locale = Locale(
            identifier: code,
        )
        let localization = try VoiceLocalization.load(
            locale: locale,
        ).dictation
        for text in ["No complaints", "Жалоб нет"] {
            let transcript = DSpeechTranscript(
                rawText: text,
                correctedText: text,
                locale: locale,
                engine: .whisperKit,
                completion: .finished,
                decodingSpans: [.init(
                    utf16Start: 0,
                    utf16Length: (text as NSString).length,
                    averageLogProbability: -0.1,
                    temperature: 0,
                    compressionRatio: 1.1,
                    recheckedText: text,
                )],
            )
            let proposal = DNeuralUltrasoundDictationProposal(
                source: .localModel,
                proposals: [
                    .init(
                        id: .patientComplaints,
                        value: .text(
                            text,
                        ),
                        sourceQuote: text,
                    ),
                ],
                unmappedFindings: [],
                rejectedFieldIds: [],
            )
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: transcript,
                parsedText: text,
                noComplaintsPattern: localization.pattern(
                    .noComplaintsValue,
                ),
            )
            #expect(
                plan.automatic.count == ((code == "en") == (text == "No complaints") ? 1 : 0),
            )
        }
    }

    @Test(
        "Both locale catalogs have the same structure and no foreign-language matching words",
    )
    func catalogsStaySynchronized() throws {
        let en = try catalogJSON(
            code: "en",
        )
        let ru = try catalogJSON(
            code: "ru",
        )
        #expect(
            structure(
                en,
            ) == structure(
                ru,
            ),
        )
        let patterns = try #require(
            (en[
                "dictation",
            ] as? [String: Any])?[
                "patterns",
            ] as? [String: String],
        )
        #expect(
            patterns.values.allSatisfy { $0.range(
                of: "[А-Яа-яЁё]",
                options: .regularExpression,
            ) == nil },
        )
    }

    @Test(
        "Local generation receives the localized examination title and preserves dictation",
        arguments: [("en", "Thyroid gland"), ("ru", "Щитовидная железа")],
    )
    func localizedExaminationContext(
        example: (String, String),
    ) {
        let (code, title) = example
        let locale = Locale(
            identifier: code,
        )
        let text = "A literal dictation with punctuation: 82 kg."
        let request = DNeuralUltrasoundDictationParseRequest(
            text: text,
            examinationTypeId: "internal-examination-id",
            examinationTypeTitle: title,
            locale: locale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: VoiceLocalizationTestSupport.dictation(
                locale: locale,
            ),
        )
        let prompt = DNeuralUltrasoundProposalGenerationConfig.userPrompt(
            for: request,
        )
        #expect(
            prompt.contains(
                "<examinationType>\(title)</examinationType>",
            ),
        )
        #expect(
            !prompt.contains(
                request.examinationTypeId,
            ),
        )
        #expect(
            prompt.contains(
                "<dictation>\n\(text)\n</dictation>",
            ),
        )
    }

    @available(iOS 26.0, *)
    @Test(
        "Foundation schemas receive localized descriptions without changing response properties",
    )
    func foundationSchemaDescriptions() throws {
        for code in ["en", "ru"] {
            let localization = try VoiceLocalization.load(
                locale: Locale(
                    identifier: code,
                ),
            ).dictation.schema
            let proposalSchema = try DNeuralUltrasoundFoundationProposalItem.arraySchema(
                localization: localization,
            )
            let data = try JSONEncoder().encode(
                proposalSchema,
            )
            let json = try JSONSerialization.jsonObject(
                with: data,
            )
            let descriptions = collectDescriptions(
                json,
            )
            #expect(
                descriptions.contains(
                    localization.evidence,
                ),
            )
            #expect(
                descriptions.contains(
                    localization.accuracy,
                ),
            )
            #expect(
                descriptions.contains(
                    localization.fieldId,
                ),
            )
            #expect(
                descriptions.contains(
                    localization.value,
                ),
            )
        }
    }

    private func catalogJSON(
        code: String,
    ) throws -> [String: Any] {
        let url = try #require(
            Bundle.main.url(
                forResource: "VoiceParsing",
                withExtension: "json",
                subdirectory: nil,
                localization: code,
            ),
        )
        return try #require(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: url,
                ),
            ) as? [String: Any],
        )
    }

    private func structure(
        _ value: Any,
        path: String = "",
    ) -> Set<String> {
        guard let object = value as? [String: Any] else { return [path] }
        return object.reduce(
            into: Set<String>(),
        ) { result, item in
            // Number dictionaries and phonetic maps have language-dependent words.
            if ["digits", "literalCharacterReplacements", "phoneticCharacterReplacements"].contains(
                item.key,
            ) {
                result.insert(
                    path + "." + item.key,
                )
            } else {
                result.formUnion(
                    structure(
                        item.value,
                        path: path + "." + item.key,
                    ),
                )
            }
        }
    }

    private func collectDescriptions(
        _ value: Any,
    ) -> [String] {
        if let object = value as? [String: Any] {
            let own = (object[
                "description",
            ] as? String).map { [$0] } ?? []
            return own + object.values.flatMap(
                collectDescriptions,
            )
        }
        if let array = value as? [Any] { return array.flatMap(
            collectDescriptions,
        ) }
        return []
    }
}
