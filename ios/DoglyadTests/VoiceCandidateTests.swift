import CryptoKit
@testable import Doglyad
@testable import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import FoundationModels
import UIKit
import XCTest

private enum VoiceParseStrategy: String {
    case production
    case exactLabels
    case explicitRules
    case naturalLanguage
    case foundationModels
}

final class VoiceCandidateTests: XCTestCase {
    @MainActor
    func testVoiceCandidate() async throws {
        guard ProcessInfo.processInfo.environment[
            "VOICE_CANDIDATE_RUN",
        ] == "1" else {
            throw XCTSkip(
                "Run with TEST_RUNNER_VOICE_CANDIDATE_RUN=1 and prepared VoiceFixtures",
            )
        }
        let bundle = Bundle(
            for: Self.self,
        )
        guard let fixtureURL = bundle.url(
            forResource: "cases",
            withExtension: "json",
            subdirectory: "VoiceFixtures",
        )
            ?? bundle.url(
                forResource: "cases",
                withExtension: "json",
            )
        else {
            XCTFail(
                "VoiceFixtures/cases.json is missing",
            )
            return
        }
        let fixture = try dictionary(
            JSONSerialization.jsonObject(
                with: Data(
                    contentsOf: fixtureURL,
                ),
            ),
        )
        if let expectedMode = ProcessInfo.processInfo.environment[
            "VOICE_EXPECTED_AUDIO_MODE",
        ] {
            guard fixture[
                "audioMode",
            ] as? String == expectedMode else {
                XCTFail(
                    "Stale voice fixture at \(fixtureURL.path): expected \(expectedMode), found \(fixture["audioMode"] ?? "missing")",
                )
                return
            }
        }
        let cases = try XCTUnwrap(
            fixture[
                "cases",
            ] as? [[String: Any]],
        )
        let generation = try XCTUnwrap(
            fixture[
                "generation",
            ] as? [String: Any],
        )
        let parameters = try DNeuralGenerationParameters(
            temperature: XCTUnwrap(
                generation[
                    "temperature",
                ] as? Double,
            ),
            maxTokens: XCTUnwrap(
                generation[
                    "maxTokens",
                ] as? Int,
            ),
            maxContextTokens: XCTUnwrap(
                generation[
                    "maxContextTokens",
                ] as? Int,
            ),
        )
        var activeFactory: DNeuralUltrasoundModelFactory?
        var activeFoundation: (any DNeuralUltrasoundProposalGeneratorProtocol)?
        var activeCode: String?
        var rows: [[String: Any]] = []
        let reportURL = try reportDestination()
        let asrOnly = ProcessInfo.processInfo.environment[
            "VOICE_ASR_ONLY",
        ] == "1"
        let asrEngineOnly = ProcessInfo.processInfo.environment[
            "VOICE_ASR_ENGINE_ONLY",
        ]
        let noFarFieldHint = ProcessInfo.processInfo.environment[
            "VOICE_ASR_NO_FAR_FIELD_HINT",
        ] == "1"
        let strategy = try XCTUnwrap(
            VoiceParseStrategy(
                rawValue: ProcessInfo.processInfo.environment[
                    "VOICE_PARSE_STRATEGY",
                ] ?? "production",
            ),
        )

        for testCase in cases {
            let id = try string(
                testCase,
                "id",
            )
            let code = try string(
                testCase,
                "locale",
            )
            let locale = Locale(
                identifier: code == "ru" ? "ru_RU" : "en_US",
            )
            let terms = try XCTUnwrap(
                testCase[
                    "contextualStrings",
                ] as? [String],
            )
            let spokenText = try string(
                testCase,
                "spokenText",
            )
            let parsingText: String = if let replay = testCase[
                "replayASR",
            ] as? [String: Any],
                replay[
                    "applyLexicon",
                ] as? Bool == true
            {
                DSpeechLexiconCorrector(
                    terms: terms,
                    localization: VoiceLocalizationTestSupport.speech(
                        locale: locale,
                    ),
                ).correct(
                    spokenText,
                )
            } else {
                spokenText
            }
            if activeCode != code {
                activeFactory?.unload()
                activeFactory = nil
                activeFoundation = nil
                activeCode = code
            }
            if activeFactory == nil {
                activeFactory = try DNeuralUltrasoundModelFactory(
                    locale: locale,
                    proposalPrompt: string(
                        testCase,
                        "proposalPrompt",
                    ),
                    parameters: parameters,
                    serverTransport: DNeuralUltrasoundUnavailableTestTransport(),
                )
            }
            let factory = try XCTUnwrap(
                activeFactory,
            )
            let foundationModelsAvailable: Bool
            let foundationModelsAvailability: String
            let foundationModelsSupportsLocale: Bool
            if #available(iOS 26.0, *) {
                let systemModel = SystemLanguageModel.default
                foundationModelsAvailability = String(
                    describing: systemModel.availability,
                )
                foundationModelsSupportsLocale = systemModel.supportsLocale(
                    locale,
                )
                foundationModelsAvailable = DNeuralUltrasoundModelFoundationModels.isAvailable(
                    locale: locale,
                )
            } else {
                foundationModelsAvailable = false
                foundationModelsAvailability = "unsupportedOS"
                foundationModelsSupportsLocale = false
            }
            let typeId = try string(
                testCase,
                "examinationTypeId",
            )
            let typeTitle = try string(
                testCase,
                "examinationTypeTitle",
            )
            var asr: [String: Any] = [:]
            if fixture[
                "textOnly",
            ] as? Bool == true {
                asr[
                    "status",
                ] = "skipped"
                asr[
                    "reason",
                ] = "Text-only control set"
            } else if let audioFile = testCase[
                "audioFile",
            ] as? String,
                let audioURL = bundle.url(
                    forResource: (audioFile as NSString).deletingPathExtension,
                    withExtension: "wav",
                    subdirectory: "VoiceFixtures",
                )
                ?? bundle.url(
                    forResource: (audioFile as NSString).deletingPathExtension,
                    withExtension: "wav",
                )
            {
                let actualHash = try SHA256.hash(
                    data: Data(
                        contentsOf: audioURL,
                    ),
                )
                .map { String(
                    format: "%02x",
                    $0,
                ) }.joined()
                if try actualHash == string(
                    testCase,
                    "audioSha256",
                ) {
                    let confidenceOnly = ProcessInfo.processInfo.environment[
                        "VOICE_ASR_CONFIDENCE_ONLY",
                    ] == "1"
                    for engine in ["speechAnalyzer", "sfSpeechRecognizer"] {
                        for hints in [false, true] {
                            let key = "\(engine)/hints=\(hints)"
                            if let asrEngineOnly, engine != asrEngineOnly || !hints {
                                asr[
                                    key,
                                ] = ["status": "skipped", "reason": "Another ASR engine selected"]
                            } else if confidenceOnly, engine != "speechAnalyzer" || !hints {
                                asr[
                                    key,
                                ] = ["status": "skipped", "reason": "Confidence-only run"]
                            } else {
                                asr[
                                    key,
                                ] = await transcribe(
                                    audioURL,
                                    locale: locale,
                                    terms: terms,
                                    engine: engine,
                                    hints: hints,
                                    noFarFieldHint: noFarFieldHint,
                                )
                            }
                        }
                    }
                } else {
                    asr[
                        "status",
                    ] = "failed"
                    asr[
                        "reason",
                    ] = "Bundled WAV hash mismatch"
                }
            } else {
                asr[
                    "status",
                ] = "failed"
                asr[
                    "reason",
                ] = "Bundled WAV missing"
            }
            let request = DNeuralUltrasoundDictationParseRequest(
                text: parsingText,
                examinationTypeId: typeId,
                examinationTypeTitle: typeTitle,
                locale: locale,
                allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                localization: VoiceLocalizationTestSupport.dictation(
                    locale: locale,
                ),
            )
            let replayTranscript: DSpeechTranscript? = if let replay = testCase[
                "replayASR",
            ] as? [String: Any],
                let rawText = replay[
                    "rawText",
                ] as? String
            {
                DSpeechTranscript(
                    rawText: rawText,
                    correctedText: parsingText,
                    locale: locale,
                    engine: .speechAnalyzer,
                    completion: .finished,
                    confidenceSpans: (replay[
                        "confidenceSpans",
                    ] as? [[String: Any]] ?? []).compactMap { span in
                        guard let start = span[
                            "utf16Start",
                        ] as? Int,
                            let length = span[
                                "utf16Length",
                            ] as? Int,
                            let confidence = span[
                                "confidence",
                            ] as? Double
                        else { return nil }
                        return DSpeechConfidenceSpan(
                            utf16Start: start,
                            utf16Length: length,
                            confidence: confidence,
                        )
                    },
                )
            } else {
                nil
            }
            if case .foundationModels = strategy, !asrOnly, activeFoundation == nil,
               foundationModelsAvailable, #available(iOS 26.0, *)
            {
                activeFoundation = try DNeuralUltrasoundFoundationProposalGenerator(
                    proposalPrompt: string(
                        testCase,
                        "proposalPrompt",
                    ),
                    parameters: parameters,
                )
            }
            var recognizedTextParse: [String: Any] = [:]
            for engine in ["speechAnalyzer", "sfSpeechRecognizer"] {
                if asrOnly {
                    recognizedTextParse[
                        engine,
                    ] = ["status": "skipped", "reason": "ASR-only run"]
                    continue
                }
                let key = "\(engine)/hints=true"
                if let result = asr[
                    key,
                ] as? [String: Any], result[
                    "status",
                ] as? String == "ok",
                    let correctedText = result[
                        "correctedText",
                    ] as? String, !correctedText.isEmpty
                {
                    let recognizedRequest = DNeuralUltrasoundDictationParseRequest(
                        text: correctedText,
                        examinationTypeId: typeId,
                        examinationTypeTitle: typeTitle,
                        locale: locale,
                        allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
                        localization: VoiceLocalizationTestSupport.dictation(
                            locale: locale,
                        ),
                    )
                    recognizedTextParse[
                        engine,
                    ] = await parse(
                        recognizedRequest,
                        factory: factory,
                        strategy: strategy,
                        foundation: activeFoundation,
                    )
                } else {
                    recognizedTextParse[
                        engine,
                    ] = ["status": "skipped", "reason": "No final transcript"]
                }
            }
            let goldTextParse: [String: Any] = if asrOnly {
                ["status": "skipped", "reason": "ASR-only run"]
            } else if fixture[
                "measureGold",
            ] as? Bool == false {
                ["status": "skipped", "reason": "Repeated gold-text parse disabled for audio run"]
            } else {
                await parse(
                    request,
                    factory: factory,
                    strategy: strategy,
                    foundation: activeFoundation,
                    transcript: replayTranscript,
                )
            }
            rows.append(
                [
                    "id": id,
                    "locale": code,
                    "examinationTypeId": typeId,
                    "parseStrategy": strategy.rawValue,
                    "parseInputText": parsingText,
                    "asr": asr,
                    "foundationModelsAvailable": foundationModelsAvailable,
                    "foundationModelsAvailability": foundationModelsAvailability,
                    "foundationModelsSupportsLocale": foundationModelsSupportsLocale,
                    "goldTextParse": goldTextParse,
                    "recognizedTextParse": recognizedTextParse,
                ],
            )
            try writeReport(
                rows: rows,
                fixture: fixture,
                to: reportURL,
            )
        }
        XCTAssertEqual(
            rows.count,
            cases.count,
        )
        print(
            "VOICE_CANDIDATE_REPORT=\(reportURL.path)",
        )
    }

    @MainActor
    private func transcribe(
        _ fileURL: URL,
        locale: Locale,
        terms: [String],
        engine: String,
        hints: Bool,
        noFarFieldHint: Bool,
    ) async -> [String: Any] {
        let started = Date()
        do {
            let result: DSpeechFileTranscription
            switch engine {
            case "speechAnalyzer":
                guard #available(iOS 26.0, *) else {
                    return ["status": "skipped", "reason": "SpeechAnalyzer requires iOS 26"]
                }
                result = try await DSpeechFileTranscriber().transcribe(
                    fileURL: fileURL,
                    locale: locale,
                    contextualStrings: terms,
                    useHints: hints,
                    isFarField: !noFarFieldHint,
                    lexiconLocalization: VoiceLocalizationTestSupport.speech(
                        locale: locale,
                    ),
                )
            case "sfSpeechRecognizer":
                result = try await DSpeechFileRecognizerSFSpeechRecognizer().transcribe(
                    fileURL: fileURL,
                    locale: locale,
                    contextualStrings: terms,
                    useHints: hints,
                    lexiconLocalization: VoiceLocalizationTestSupport.speech(
                        locale: locale,
                    ),
                )
            default:
                return ["status": "failed", "reason": "Unknown engine"]
            }
            return [
                "status": "ok",
                "rawText": result.rawText,
                "correctedText": result.correctedText,
                "confidenceSpans": result.confidenceSpans.map { span in
                    [
                        "utf16Start": span.utf16Start,
                        "utf16Length": span.utf16Length,
                        "confidence": span.confidence,
                    ]
                },
                "elapsedSeconds": Date().timeIntervalSince(
                    started,
                ),
            ]
        } catch {
            return [
                "status": "failed",
                "reason": String(
                    describing: error,
                ),
                "elapsedSeconds": Date().timeIntervalSince(
                    started,
                ),
            ]
        }
    }

    @MainActor
    private func parse(
        _ request: DNeuralUltrasoundDictationParseRequest,
        factory: DNeuralUltrasoundModelFactory,
        strategy: VoiceParseStrategy,
        foundation: (any DNeuralUltrasoundProposalGeneratorProtocol)?,
        transcript: DSpeechTranscript? = nil,
    ) async -> [String: Any] {
        let started = Date()
        do {
            let proposal: DNeuralUltrasoundDictationProposal
            switch strategy {
            case .production:
                proposal = try await factory.model().parseProposals(
                    request: request,
                )
            case .exactLabels:
                proposal = DNeuralUltrasoundDictationLabeledFormParser.parse(
                    request: request,
                ) ?? DNeuralUltrasoundDictationProposal(
                    source: .labeledDictation,
                    proposals: [],
                    unmappedFindings: [],
                    rejectedFieldIds: [],
                )
            case .explicitRules:
                proposal = DNeuralUltrasoundDictationProposalReconciler.reconcile(
                    request: request,
                    labeled: DNeuralUltrasoundDictationLabeledFormParser.parse(
                        request: request,
                    ),
                    explicit: DNeuralUltrasoundDictationExplicitFactsExtractor.extract(
                        request: request,
                    ),
                    generated: nil,
                )
            case .naturalLanguage:
                proposal = DNeuralUltrasoundDictationNaturalLanguageParser.parse(
                    request: request,
                )
            case .foundationModels:
                guard let foundation else { throw DNeuralModelError.unavailable }
                proposal = try await DNeuralUltrasoundProposalProcessor.validate(
                    generated: foundation.generateProposals(
                        request: request,
                    ),
                    request: request,
                )
            }
            let source = switch proposal.source {
            case .labeledDictation:
                "labeledDictation"
            case .explicitFacts:
                "explicitFacts"
            case .localModel:
                "localModel"
            case .serverModel:
                "serverModel"
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            var fields: [String: Any] = [:]
            var quotes: [String: String] = [:]
            var warnings: [String: [String]] = [:]
            var accuracies: [String: String] = [:]
            for item in proposal.proposals {
                let value: Any = switch item.value {
                case let .text(
                    text,
                ): text
                case let .gender(
                    gender,
                ): gender.rawValue
                case let .date(
                    date,
                ): formatter.string(
                        from: date,
                    )
                case let .number(
                    number,
                ): number
                }
                fields[
                    item.id.rawValue,
                ] = value
                quotes[
                    item.id.rawValue,
                ] = item.sourceQuote
                warnings[
                    item.id.rawValue,
                ] = item.warnings.map(
                    \.rawValue,
                )
                accuracies[
                    item.id.rawValue,
                ] = item.accuracy.rawValue
            }
            var result: [String: Any] = [
                "status": "ok",
                "source": source,
                "fields": fields,
                "sourceQuotes": quotes,
                "warnings": warnings,
                "accuracies": accuracies,
                "unmappedFindings": proposal.unmappedFindings,
                "rejectedFieldIds": proposal.rejectedFieldIds.map(
                    \.rawValue,
                ),
                "elapsedSeconds": Date().timeIntervalSince(
                    started,
                ),
            ]
            if let transcript {
                let review = ScanSpeechConfidencePolicy.plan(
                    proposal: proposal,
                    transcript: transcript,
                    parsedText: request.text,
                    noComplaintsPattern: VoiceLocalizationTestSupport.dictation(
                        locale: transcript.locale,
                    ).pattern(
                        .noComplaintsValue,
                    ),
                )
                result[
                    "automaticFieldIds",
                ] = review.automatic.map(
                    \.id.rawValue,
                )
                result[
                    "uncertainFieldIds",
                ] = review.uncertain.map(
                    \.id.rawValue,
                )
            }
            return result
        } catch {
            return [
                "status": "failed",
                "reason": String(
                    describing: error,
                ),
                "elapsedSeconds": Date().timeIntervalSince(
                    started,
                ),
            ]
        }
    }

    private func reportDestination() throws -> URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask,
        )[
            0,
        ]
        try FileManager.default.createDirectory(
            at: documents,
            withIntermediateDirectories: true,
        )
        let runID = ProcessInfo.processInfo.environment[
            "VOICE_REPORT_ID",
        ]
        let name = runID.map { "voice-candidate-ios-\($0).json" } ?? "voice-candidate-ios.json"
        return documents.appendingPathComponent(
            name,
        )
    }

    private func writeReport(
        rows: [[String: Any]],
        fixture: [String: Any],
        to destination: URL,
    ) throws {
        let report: [String: Any] = [
            "schemaVersion": 1,
            "platform": platformName,
            "runId": ProcessInfo.processInfo.environment[
                "VOICE_REPORT_ID",
            ] as Any? ?? NSNull(),
            "systemVersion": UIDevice.current.systemVersion,
            "deviceModel": UIDevice.current.model,
            "fixtureRegressionSha256": fixture[
                "regressionSha256",
            ] ?? NSNull(),
            "fixtureControlSha256": fixture[
                "controlSha256",
            ] ?? NSNull(),
            "fixtureVoiceBlindSha256": fixture[
                "voiceBlindSha256",
            ] ?? NSNull(),
            "fixtureFreeformDevelopmentSha256": fixture[
                "freeformDevelopmentSha256",
            ] ?? NSNull(),
            "fixtureHoldoutV4Sha256": fixture[
                "holdoutV4Sha256",
            ] ?? NSNull(),
            "fixtureHoldoutV5Sha256": fixture[
                "holdoutV5Sha256",
            ] ?? NSNull(),
            "fixtureHoldoutV6Sha256": fixture[
                "holdoutV6Sha256",
            ] ?? NSNull(),
            "fixtureHoldoutV7Sha256": fixture[
                "holdoutV7Sha256",
            ] ?? NSNull(),
            "fixtureHoldoutV8Sha256": fixture[
                "holdoutV8Sha256",
            ] ?? NSNull(),
            "fixtureAdversarialSha256": fixture[
                "adversarialSha256",
            ] ?? NSNull(),
            "fixtureSplit": fixture[
                "split",
            ] ?? "regression",
            "fixtureAudioManifestSha256": fixture[
                "audioManifestSha256",
            ] ?? NSNull(),
            "fixtureAudioMode": fixture[
                "audioMode",
            ] ?? NSNull(),
            "fixtureAudioVariant": fixture[
                "audioVariant",
            ] ?? NSNull(),
            "fixturePromptSha256": fixture[
                "promptSha256",
            ] ?? NSNull(),
            "fixtureContextualStringsSha256": fixture[
                "contextualStringsSha256",
            ] ?? NSNull(),
            "fixtureApplicationSha256": fixture[
                "applicationSha256",
            ] ?? NSNull(),
            "fixtureSourceFilesSha256": fixture[
                "sourceFilesSha256",
            ] ?? NSNull(),
            "fixtureInputSource": fixture[
                "inputSource",
            ] ?? "originalText",
            "asrNoFarFieldHint": ProcessInfo.processInfo.environment[
                "VOICE_ASR_NO_FAR_FIELD_HINT",
            ] == "1",
            "fixtureASRRecognizer": fixture[
                "asrRecognizer",
            ] ?? NSNull(),
            "fixtureASRReportSha256": fixture[
                "asrReportSha256",
            ] ?? NSNull(),
            "fixtureReplayLexiconApplied": fixture[
                "replayLexiconApplied",
            ] ?? false,
            "results": rows,
        ]
        try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys],
        )
        .write(
            to: destination,
            options: .atomic,
        )
    }

    private var platformName: String {
        #if targetEnvironment(
            simulator,
        )
        "iOS Simulator"
        #else
        "iOS"
        #endif
    }

    private func dictionary(
        _ value: Any,
    ) throws -> [String: Any] {
        try XCTUnwrap(
            value as? [String: Any],
        )
    }

    private func string(
        _ dictionary: [String: Any],
        _ key: String,
    ) throws -> String {
        try XCTUnwrap(
            dictionary[
                key,
            ] as? String,
        )
    }
}
