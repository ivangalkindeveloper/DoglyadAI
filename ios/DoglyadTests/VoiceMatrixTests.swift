import CryptoKit
@testable import Doglyad
@testable import DoglyadNeuralModel
@testable import DoglyadSpeech
import FirebaseAppCheck
import FirebaseCore
import Foundation
import FoundationModels
import WhisperKit
import XCTest

@available(iOS 26.0, *)
final class VoiceMatrixTests: XCTestCase {
    @MainActor
    func testASRMatrix() async throws {
        guard let engine = ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_ASR",
        ] else {
            throw XCTSkip(
                "Requires an explicitly selected matrix ASR",
            )
        }
        let fixture = try loadFixture()
        let cases = try XCTUnwrap(
            fixture[
                "cases",
            ] as? [[String: Any]],
        )
        let model: WhisperKit? = if engine == "whisperKit" {
            try await DSpeechWhisperKitModel.shared.load()
        } else {
            nil
        }
        let handle = try outputHandle()
        defer {
            try? handle.close()
        }
        var tokenPublishedAt = Date.distantPast
        for (index, item) in cases.enumerated() {
            if Date().timeIntervalSince(
                tokenPublishedAt,
            ) > 1200 {
                try await publishAppCheckTokenIfRequested()
                tokenPublishedAt = Date()
            }
            var row = item
            row[
                "recognizer",
            ] = engine
            let started = Date()
            do {
                let locale = try Locale(
                    identifier: text(
                        item,
                        "locale",
                    ),
                )
                let file = try audioURL(
                    item,
                )
                let data = try Data(
                    contentsOf: file,
                )
                XCTAssertEqual(
                    SHA256.hash(
                        data: data,
                    ).map {
                        String(
                            format: "%02x",
                            $0,
                        )
                    }.joined(),
                    try text(
                        item,
                        "audioSha256",
                    ),
                )
                let terms = try XCTUnwrap(
                    item[
                        "contextualStrings",
                    ] as? [String],
                )
                if let model {
                    let result = try await DSpeechWhisperKitTranscription.transcribe(
                        model: model,
                        audioPath: file.path,
                        language: text(
                            item,
                            "locale",
                        ),
                        duration: XCTUnwrap(
                            item[
                                "durationSeconds",
                            ] as? Double,
                        ),
                    )
                    row[
                        "rawText",
                    ] = result.rawText
                    row[
                        "correctedText",
                    ] = DSpeechLexiconCorrector(
                        terms: terms,
                        localization: VoiceLocalizationTestSupport.speech(
                            locale: locale,
                        ),
                    ).correct(
                        result.rawText,
                        decodingSpans: result.decodingSpans,
                    )
                    row[
                        "decodingSeconds",
                    ] = result.decodingSeconds
                    row[
                        "recheckSeconds",
                    ] = result.recheckSeconds
                    row[
                        "decodingSpans",
                    ] = result.decodingSpans.map { span in
                        [
                            "utf16Start": span.utf16Start,
                            "utf16Length": span.utf16Length,
                            "averageLogProbability": span.averageLogProbability,
                            "temperature": span.temperature,
                            "compressionRatio": span.compressionRatio,
                            "recheckedText": span.recheckedText as Any? ?? NSNull(),
                            "isSpeechDetected": span.isSpeechDetected as Any? ?? NSNull(),
                        ] as [String: Any]
                    }
                } else {
                    let result: DSpeechFileTranscription
                    switch engine {
                    case "speechAnalyzer":
                        result = try await DSpeechFileTranscriber().transcribe(
                            fileURL: file,
                            locale: locale,
                            contextualStrings: terms,
                            isHintingEnabled: true,
                            isFarField: true,
                            lexiconLocalization: VoiceLocalizationTestSupport.speech(
                                locale: locale,
                            ),
                        )
                    case "sfSpeechRecognizer":
                        result = try await DSpeechFileRecognizerSFSpeechRecognizer().transcribe(
                            fileURL: file,
                            locale: locale,
                            contextualStrings: terms,
                            isHintingEnabled: true,
                            lexiconLocalization: VoiceLocalizationTestSupport.speech(
                                locale: locale,
                            ),
                        )
                    default:
                        throw CocoaError(
                            .featureUnsupported,
                        )
                    }
                    row[
                        "rawText",
                    ] = result.rawText
                    row[
                        "correctedText",
                    ] = result.correctedText
                    row[
                        "confidenceSpans",
                    ] = result.confidenceSpans.map {
                        ["utf16Start": $0.utf16Start, "utf16Length": $0.utf16Length, "confidence": $0.confidence] as [String: Any]
                    }
                }
                guard !(row[
                    "rawText",
                ] as? String ?? "").trimmingCharacters(
                    in: .whitespacesAndNewlines,
                ).isEmpty else {
                    throw CocoaError(
                        .coderValueNotFound,
                    )
                }
                row[
                    "status",
                ] = "ok"
            } catch {
                row[
                    "status",
                ] = "failed"
                row[
                    "reason",
                ] = String(
                    describing: error,
                )
            }
            row[
                "seconds",
            ] = Date().timeIntervalSince(
                started,
            )
            try append(
                row,
                to: handle,
            )
            print(
                "VOICE_MATRIX_ASR \(engine) \(index + 1)/\(cases.count) \(row["status"] ?? "missing")",
            )
        }
    }

    @MainActor
    func testExtractionMatrix() async throws {
        guard ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_EXTRACTION",
        ] == "1" else {
            throw XCTSkip(
                "Requires prepared matrix transcripts",
            )
        }
        let fixture = try loadFixture()
        let cases = try XCTUnwrap(
            fixture[
                "cases",
            ] as? [[String: Any]],
        )
        let configuration = try XCTUnwrap(
            fixture[
                "configuration",
            ] as? [String: [String: Any]],
        )
        let isServer = ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_SERVER",
        ] == "1"
        let selectedMethods = ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_METHODS",
        ] ?? "all"
        let handle = try outputHandle()
        defer {
            try? handle.close()
        }
        var generatedCache: [String: DNeuralUltrasoundProposalGenerationResponse] = [:]
        var tokenPublishedAt = Date.distantPast
        for (index, item) in cases.enumerated() {
            // The rules and server replay paths are synchronous. Let UIKit
            // process events and release temporary Foundation objects per row.
            try await Task.sleep(
                for: .milliseconds(
                    1,
                ),
            )
            if Date().timeIntervalSince(
                tokenPublishedAt,
            ) > 1200 {
                try await publishAppCheckTokenIfRequested()
                tokenPublishedAt = Date()
            }
            var row = item
            let code = try text(
                item,
                "locale",
            )
            let locale = Locale(
                identifier: code,
            )
            let config = try XCTUnwrap(
                configuration[
                    code,
                ],
            )
            var parsingText = try text(
                item,
                "text",
            )
            if item[
                "isLexiconRequired",
            ] as? Bool == true {
                parsingText = try DSpeechLexiconCorrector(
                    terms: XCTUnwrap(
                        item[
                            "contextualStrings",
                        ] as? [String],
                    ),
                    localization: VoiceLocalizationTestSupport.speech(
                        locale: locale,
                    ),
                ).correct(
                    parsingText,
                )
            }
            row[
                "text",
            ] = parsingText
            let request = try DNeuralUltrasoundDictationParseRequest(
                text: parsingText,
                examinationTypeId: text(
                    item,
                    "examinationTypeId",
                ),
                examinationTypeTitle: text(
                    item,
                    "examinationTypeTitle",
                ),
                locale: locale,
                allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: locale,
                ),
            )
            let processor = DNeuralUltrasoundProposalProcessor(
                request: request,
            )
            var methods: [String: Any] = [:]
            if !isServer, selectedMethods != "foundation" {
                let rules: [(String, () -> DNeuralUltrasoundDictationProposal)] = [
                    ("exactLabels", {
                        DNeuralUltrasoundDictationLabeledFormParser.parse(
                            request: request,
                        )
                            ?? DNeuralUltrasoundDictationProposal(
                                source: .labeledDictation,
                                proposals: [],
                            )
                    }),
                    ("explicitRules", {
                        processor.deterministic
                    }),
                    ("naturalLanguage", {
                        DNeuralUltrasoundDictationNaturalLanguageParser.parse(
                            request: request,
                        )
                    }),
                ]
                for (name, parse) in rules {
                    let started = Date()
                    methods[
                        name,
                    ] = try applied(
                        parse(),
                        input: row,
                        seconds: Date().timeIntervalSince(
                            started,
                        ),
                    )
                }
            }
            if selectedMethods == "rules" {
                row[
                    "methods",
                ] = methods
                try append(
                    row,
                    to: handle,
                )
                print(
                    "VOICE_MATRIX_RULES \(index + 1)/\(cases.count)",
                )
                continue
            }
            let isMedgemma15 = item[
                "generationModelId",
            ] as? String == "google/medgemma-1.5-4b-it"
            let modelName = isServer ? (isMedgemma15 ? "medgemma15" : "medgemma") : "foundationModels"
            let productionModelName = isServer ? (isMedgemma15 ? "productionMedgemma15" : "productionMedgemma") : "productionFoundation"
            let started = Date()
            do {
                let generated: DNeuralUltrasoundProposalGenerationResponse
                if isServer {
                    if item[
                        "status",
                    ] as? String == "failed" {
                        throw NSError(
                            domain: "VoiceMatrixServerGeneration",
                            code: 502,
                            userInfo: [NSLocalizedDescriptionKey: item[
                                "reason",
                            ] as? String ?? "Invalid server generation"],
                        )
                    }
                    let response = try JSONDecoder().decode(
                        DNeuralUltrasoundVoiceFormParseResponseDTO.self,
                        from: JSONSerialization.data(
                            withJSONObject: XCTUnwrap(
                                item[
                                    "serverResponse",
                                ],
                            ),
                        ),
                    )
                    generated = DNeuralUltrasoundProposalGenerationResponse(
                        serverResponse: response,
                    )
                } else {
                    guard SystemLanguageModel.default.supportsLocale(
                        locale,
                    ),
                        DNeuralUltrasoundModelFoundationModels.isAvailable(
                            locale: locale,
                        )
                    else {
                        methods[
                            modelName,
                        ] = ["status": "unavailable", "reason": "Foundation Models locale/device unavailable"]
                        methods[
                            "productionFoundation",
                        ] = ["status": "unavailable", "reason": "Foundation Models locale/device unavailable"]
                        row[
                            "methods",
                        ] = methods
                        try append(
                            row,
                            to: handle,
                        )
                        continue
                    }
                    let key = code + ":" + request.examinationTypeId + ":" + request.text
                    if let cached = generatedCache[
                        key,
                    ] {
                        generated = cached
                        row[
                            "isGenerationReused",
                        ] = true
                    } else {
                        let generator = try DNeuralUltrasoundFoundationProposalGenerator(
                            proposalPrompt: text(
                                config,
                                "proposalPrompt",
                            ),
                            parameters: DNeuralGenerationParameters(
                                temperature: XCTUnwrap(
                                    config[
                                        "temperature",
                                    ] as? Double,
                                ),
                                maxTokens: XCTUnwrap(
                                    config[
                                        "maxTokens",
                                    ] as? Int,
                                ),
                                maxContextTokens: XCTUnwrap(
                                    config[
                                        "maxContextTokens",
                                    ] as? Int,
                                ),
                            ),
                        )
                        generated = try await generator.generateProposals(
                            request: request,
                        )
                        generatedCache[
                            key,
                        ] = generated
                        row[
                            "isGenerationReused",
                        ] = false
                    }
                }
                row[
                    "rawGeneration",
                ] = try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(
                        generated,
                    ),
                )
                let source: DNeuralDictationProposalSource = isServer ? .serverModel : .localModel
                let validated = try DNeuralUltrasoundProposalProcessor.validate(
                    generated: generated,
                    request: request,
                    source: source,
                )
                let reconciled = try processor.process(
                    generated: generated,
                    source: source,
                )
                let seconds = Date().timeIntervalSince(
                    started,
                )
                methods[
                    modelName,
                ] = try applied(
                    validated,
                    input: row,
                    seconds: seconds,
                )
                methods[
                    productionModelName,
                ] = try applied(
                    reconciled,
                    input: row,
                    seconds: seconds,
                )
            } catch {
                methods[
                    modelName,
                ] = ["status": "failed", "reason": String(
                    describing: error,
                ), "seconds": Date().timeIntervalSince(
                    started,
                )]
                if !isServer, !processor.deterministic.proposals.isEmpty {
                    methods[
                        "productionFoundation",
                    ] = try applied(
                        processor.deterministic,
                        input: row,
                        seconds: Date().timeIntervalSince(
                            started,
                        ),
                    )
                } else {
                    methods[
                        productionModelName,
                    ] = methods[
                        modelName,
                    ]
                }
            }
            row[
                "methods",
            ] = methods
            try append(
                row,
                to: handle,
            )
            print(
                "VOICE_MATRIX_EXTRACTION \(index + 1)/\(cases.count)",
            )
        }
    }

    private func loadFixture() throws -> [String: Any] {
        let name = ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_FIXTURE",
        ] ?? "matrix-asr"
        let bundle = Bundle(
            for: Self.self,
        )
        let url = try XCTUnwrap(
            bundle.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "VoiceFixtures",
            )
                ?? bundle.url(
                    forResource: name,
                    withExtension: "json",
                ),
        )
        return try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: url,
                ),
            ) as? [String: Any],
        )
    }

    @MainActor
    private func publishAppCheckTokenIfRequested() async throws {
        guard ProcessInfo.processInfo.environment[
            "VOICE_MATRIX_EXPORT_TOKEN",
        ] == "1" else {
            return
        }
        #if DEBUG || targetEnvironment(
            simulator,
        )
        throw CocoaError(
            .featureUnsupported,
        )
        #else
        for _ in 0 ..< 100 where FirebaseApp.app() == nil {
            try await Task.sleep(
                for: .milliseconds(
                    100,
                ),
            )
        }
        let token = try await AppCheck.appCheck().token(
            forcingRefresh: true,
        )
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask,
        )[
            0,
        ]
        try token.token.write(
            to: directory.appendingPathComponent(
                "voice-matrix-app-check-token.txt",
            ),
            atomically: true,
            encoding: .utf8,
        )
        #endif
    }

    private func audioURL(
        _ item: [String: Any],
    ) throws -> URL {
        let name = try text(
            item,
            "audioFile",
        )
        let bundle = Bundle(
            for: Self.self,
        )
        return try XCTUnwrap(
            bundle.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: "wav",
                subdirectory: "VoiceFixtures",
            )
                ?? bundle.url(
                    forResource: (name as NSString).deletingPathExtension,
                    withExtension: "wav",
                ),
        )
    }

    private func outputHandle() throws -> FileHandle {
        let name = ProcessInfo.processInfo.environment[
            "VOICE_REPORT_ID",
        ] ?? "matrix"
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask,
        )[
            0,
        ]
        let url = directory.appendingPathComponent(
            "voice-matrix-\(name).jsonl",
        )
        FileManager.default.createFile(
            atPath: url.path,
            contents: nil,
        )
        print(
            "VOICE_MATRIX_REPORT=\(url.path)",
        )
        return try FileHandle(
            forWritingTo: url,
        )
    }

    private func append(
        _ row: [String: Any],
        to handle: FileHandle,
    ) throws {
        var data = try JSONSerialization.data(
            withJSONObject: row,
            options: [.sortedKeys],
        )
        data.append(
            0x0A,
        )
        try handle.write(
            contentsOf: data,
        )
        try handle.synchronize()
    }

    private func text(
        _ item: [String: Any],
        _ key: String,
    ) throws -> String {
        try XCTUnwrap(
            item[
                key,
            ] as? String,
        )
    }

    private func applied(
        _ proposal: DNeuralUltrasoundDictationProposal,
        input: [String: Any],
        seconds: Double,
    ) throws -> [String: Any] {
        let before = USExaminationDraftForm(
            examinationNumber: "KEEP-ID",
            patientName: "KEEP-NAME",
            patientGender: .male,
            patientDateOfBirth: Date(
                timeIntervalSince1970: 0,
            ),
            patientHeightCM: "199",
            patientWeightKG: "99",
            patientComplaints: "KEEP-COMPLAINTS",
            examinationDescription: "KEEP-DESCRIPTION",
        )
        let engine: DSpeechEngine? = switch input[
            "recognizer",
        ] as? String {
        case "whisperKit": .whisperKit
        case "speechAnalyzer": .speechAnalyzer
        case "sfSpeechRecognizer": .sfSpeechRecognizer
        default: nil
        }
        var automatic: [DNeuralUltrasoundVoiceFieldProposal] = []
        var uncertain = proposal.proposals
        if let engine {
            let locale = try Locale(
                identifier: text(
                    input,
                    "locale",
                ),
            )
            let confidence = (input[
                "confidenceSpans",
            ] as? [[String: Any]] ?? []).compactMap { span -> DSpeechConfidenceSpan? in
                guard let start = span[
                    "utf16Start",
                ] as? Int, let length = span[
                    "utf16Length",
                ] as? Int,
                    let confidence = span[
                        "confidence",
                    ] as? Double
                else {
                    return nil
                }
                return DSpeechConfidenceSpan(
                    utf16Start: start,
                    utf16Length: length,
                    confidence: confidence,
                )
            }
            let decoding = (input[
                "decodingSpans",
            ] as? [[String: Any]] ?? []).compactMap { span -> DSpeechDecodingSpan? in
                guard let start = span[
                    "utf16Start",
                ] as? Int, let length = span[
                    "utf16Length",
                ] as? Int,
                    let probability = span[
                        "averageLogProbability",
                    ] as? Double,
                    let temperature = span[
                        "temperature",
                    ] as? Double,
                    let compression = span[
                        "compressionRatio",
                    ] as? Double
                else {
                    return nil
                }
                return DSpeechDecodingSpan(
                    utf16Start: start,
                    utf16Length: length,
                    averageLogProbability: probability,
                    temperature: temperature,
                    compressionRatio: compression,
                    recheckedText: span[
                        "recheckedText",
                    ] as? String,
                    isSpeechDetected: span[
                        "isSpeechDetected",
                    ] as? Bool,
                )
            }
            let transcript = try DSpeechTranscript(
                rawText: text(
                    input,
                    "rawText",
                ),
                correctedText: text(
                    input,
                    "text",
                ),
                locale: locale,
                engine: engine,
                completion: .finished,
                confidenceSpans: confidence,
                decodingSpans: decoding,
            )
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: transcript,
                parsedText: transcript.correctedText,
                noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                    locale: locale,
                ).pattern(
                    .noComplaintsValue,
                ),
            )
            automatic = plan.automatic
            uncertain = plan.uncertain
        }
        let afterAutomatic = try XCTUnwrap(
            ScanFormPatch.apply(
                automatic,
                to: before,
            ),
        )
        let after = try XCTUnwrap(
            ScanFormPatch.apply(
                uncertain,
                to: afterAutomatic,
            ),
        )
        var fields: [String: Any] = [:]
        var quotes: [String: String] = [:]
        var warnings: [String: [String]] = [:]
        var accuracies: [String: String] = [:]
        for item in proposal.proposals {
            let key = item.id.rawValue
            fields[
                key,
            ] = value(
                item.value,
            )
            quotes[
                key,
            ] = item.sourceQuote
            warnings[
                key,
            ] = item.warnings.map(
                \.rawValue,
            )
            accuracies[
                key,
            ] = item.accuracy.rawValue
        }
        let form = formValues(
            after,
        )
        let original = formValues(
            before,
        )
        for id in DNeuralUltrasoundVoiceFieldId.allCases {
            if let expected = fields[
                id.rawValue,
            ] {
                if id == .patientHeightCM || id == .patientWeightKG {
                    XCTAssertEqual(
                        Double(
                            form[
                                id.rawValue,
                            ] as? String ?? "",
                        ),
                        (expected as? NSNumber)?.doubleValue,
                    )
                } else {
                    XCTAssertEqual(
                        form[
                            id.rawValue,
                        ] as? AnyHashable,
                        expected as? AnyHashable,
                    )
                }
            } else {
                XCTAssertEqual(
                    form[
                        id.rawValue,
                    ] as? AnyHashable,
                    original[
                        id.rawValue,
                    ] as? AnyHashable,
                )
            }
        }
        return [
            "status": "ok",
            "fields": fields,
            "sourceQuotes": quotes,
            "warnings": warnings,
            "accuracies": accuracies,
            "automaticFieldIds": automatic.map(
                \.id.rawValue,
            ),
            "reviewFieldIds": uncertain.map(
                \.id.rawValue,
            ),
            "isAutomaticPolicySupported": engine != nil,
            "formAfterAutomatic": formValues(
                afterAutomatic,
            ),
            "formAfterConfirmation": form,
            "seconds": seconds,
        ]
    }

    private func value(
        _ value: DNeuralVoiceFieldValue,
    ) -> Any {
        switch value {
        case let .text(
            value,
        ): value
        case let .number(
            value,
        ): value
        case let .gender(
            value,
        ): value.rawValue
        case let .date(
            value,
        ):
            dateString(
                value,
            )
        }
    }

    private func dateString(
        _ date: Date,
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(
            identifier: .gregorian,
        )
        formatter.locale = Locale(
            identifier: "en_US_POSIX",
        )
        formatter.timeZone = TimeZone(
            secondsFromGMT: 0,
        )
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(
            from: date,
        )
    }

    private func formValues(
        _ form: USExaminationDraftForm,
    ) -> [String: Any] {
        [
            "examinationNumber": form.examinationNumber,
            "patientName": form.patientName,
            "patientGender": form.patientGender.rawValue,
            "patientDateOfBirth": dateString(
                form.patientDateOfBirth,
            ),
            "patientHeightCM": form.patientHeightCM,
            "patientWeightKG": form.patientWeightKG,
            "patientComplaints": form.patientComplaints,
            "examinationDescription": form.examinationDescription,
        ]
    }
}
