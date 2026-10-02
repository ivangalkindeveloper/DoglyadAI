import CryptoKit
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import UIKit
import XCTest

final class VoiceCandidateTests: XCTestCase {
    @MainActor
    func testVoiceCandidate() async throws {
        guard ProcessInfo.processInfo.environment["VOICE_CANDIDATE_RUN"] == "1" else {
            throw XCTSkip("Run with TEST_RUNNER_VOICE_CANDIDATE_RUN=1 and prepared VoiceFixtures")
        }
        let bundle = Bundle(for: Self.self)
        guard let fixtureURL = bundle.url(forResource: "cases", withExtension: "json", subdirectory: "VoiceFixtures")
            ?? bundle.url(forResource: "cases", withExtension: "json")
        else {
            XCTFail("VoiceFixtures/cases.json is missing")
            return
        }
        let fixture = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)))
        if let expectedMode = ProcessInfo.processInfo.environment["VOICE_EXPECTED_AUDIO_MODE"] {
            guard fixture["audioMode"] as? String == expectedMode else {
                XCTFail("Stale voice fixture at \(fixtureURL.path): expected \(expectedMode), found \(fixture["audioMode"] ?? "missing")")
                return
            }
        }
        let cases = try XCTUnwrap(fixture["cases"] as? [[String: Any]])
        let generation = try XCTUnwrap(fixture["generation"] as? [String: Any])
        let parameters = try DExaminationGenerationParameters(
            temperature: XCTUnwrap(generation["temperature"] as? Double),
            maxTokens: XCTUnwrap(generation["maxTokens"] as? Int),
            maxContextTokens: XCTUnwrap(generation["maxContextTokens"] as? Int)
        )
        var activeFactory: DExaminationNeuralModelFactory?
        var activeMLX: DExaminationNeuralModelMLX?
        var activeCode: String?
        var rows: [[String: Any]] = []
        let reportURL = try reportDestination()
        let asrOnly = ProcessInfo.processInfo.environment["VOICE_ASR_ONLY"] == "1"

        for testCase in cases {
            let id = try string(testCase, "id")
            let code = try string(testCase, "locale")
            let locale = Locale(identifier: code == "ru" ? "ru_RU" : "en_US")
            let terms = try XCTUnwrap(testCase["contextualStrings"] as? [String])
            let spokenText = try string(testCase, "spokenText")
            if activeCode != code {
                activeFactory?.unload()
                activeFactory = nil
                activeMLX = nil
                activeCode = code
            }
            if activeFactory == nil {
                activeFactory = try DExaminationNeuralModelFactory(
                    locale: locale,
                    systemPrompt: string(testCase, "systemPrompt"),
                    proposalPrompt: string(testCase, "proposalPrompt"),
                    parameters: parameters
                )
            }
            let factory = try XCTUnwrap(activeFactory)
            let forceMLX = ProcessInfo.processInfo.environment["VOICE_FORCE_MLX"] == "1"
            let mlxAvailable = DExaminationNeuralModelMLX.isAvailable(locale: locale, parameters: parameters)
            let foundationModelsAvailable: Bool
            if #available(iOS 26.0, *) {
                foundationModelsAvailable = DExaminationNeuralModelFoundationModels.isAvailable(
                    locale: locale, parameters: parameters
                )
            } else {
                foundationModelsAvailable = false
            }
            let typeId = try string(testCase, "examinationTypeId")
            var asr: [String: Any] = [:]
            if fixture["textOnly"] as? Bool == true {
                asr["status"] = "skipped"
                asr["reason"] = "Text-only control set"
            } else if let audioFile = testCase["audioFile"] as? String,
                      let audioURL = bundle.url(forResource: (audioFile as NSString).deletingPathExtension,
                                                withExtension: "wav", subdirectory: "VoiceFixtures")
                      ?? bundle.url(forResource: (audioFile as NSString).deletingPathExtension, withExtension: "wav")
            {
                let actualHash = try SHA256.hash(data: Data(contentsOf: audioURL))
                    .map { String(format: "%02x", $0) }.joined()
                if try actualHash == string(testCase, "audioSha256") {
                    let confidenceOnly = ProcessInfo.processInfo.environment["VOICE_ASR_CONFIDENCE_ONLY"] == "1"
                    for engine in ["speechAnalyzer", "sfSpeechRecognizer"] {
                        for hints in [false, true] {
                            let key = "\(engine)/hints=\(hints)"
                            if confidenceOnly, engine != "speechAnalyzer" || !hints {
                                asr[key] = ["status": "skipped", "reason": "Confidence-only run"]
                            } else {
                                asr[key] = await transcribe(audioURL, locale: locale, terms: terms,
                                                            engine: engine, hints: hints)
                            }
                        }
                    }
                } else {
                    asr["status"] = "failed"
                    asr["reason"] = "Bundled WAV hash mismatch"
                }
            } else {
                asr["status"] = "failed"
                asr["reason"] = "Bundled WAV missing"
            }
            let request = DictationParseRequest(
                text: spokenText, examinationTypeId: typeId, locale: locale,
                allowedFields: VoiceFieldId.allCases
            )
            var mlxLoadError: String?
            if forceMLX, !asrOnly, activeMLX == nil {
                do {
                    guard mlxAvailable else { throw DExaminationNeuralModelError.unavailable }
                    activeMLX = try await DExaminationNeuralModelMLX(
                        systemPrompt: string(testCase, "systemPrompt"),
                        proposalPrompt: string(testCase, "proposalPrompt"),
                        parameters: parameters
                    )
                } catch {
                    mlxLoadError = String(describing: error)
                }
            }
            var recognizedTextParse: [String: Any] = [:]
            for engine in ["speechAnalyzer", "sfSpeechRecognizer"] {
                if asrOnly {
                    recognizedTextParse[engine] = ["status": "skipped", "reason": "ASR-only run"]
                    continue
                }
                let key = "\(engine)/hints=true"
                if let result = asr[key] as? [String: Any], result["status"] as? String == "ok",
                   let correctedText = result["correctedText"] as? String, !correctedText.isEmpty
                {
                    let recognizedRequest = DictationParseRequest(
                        text: correctedText, examinationTypeId: typeId, locale: locale,
                        allowedFields: VoiceFieldId.allCases
                    )
                    if let mlxLoadError {
                        recognizedTextParse[engine] = ["status": "failed", "reason": mlxLoadError]
                    } else {
                        recognizedTextParse[engine] = await parse(recognizedRequest, factory: factory, forcedMLX: activeMLX)
                    }
                } else {
                    recognizedTextParse[engine] = ["status": "skipped", "reason": "No final transcript"]
                }
            }
            let goldTextParse: [String: Any]
            if asrOnly {
                goldTextParse = ["status": "skipped", "reason": "ASR-only run"]
            } else if fixture["measureGold"] as? Bool == false {
                goldTextParse = ["status": "skipped", "reason": "Repeated gold-text parse disabled for audio run"]
            } else {
                if let mlxLoadError {
                    goldTextParse = ["status": "failed", "reason": mlxLoadError]
                } else {
                    goldTextParse = await parse(request, factory: factory, forcedMLX: activeMLX)
                }
            }
            rows.append([
                "id": id, "locale": code, "examinationTypeId": typeId,
                "asr": asr,
                "foundationModelsAvailable": foundationModelsAvailable,
                "mlxAvailable": mlxAvailable,
                "goldTextParse": goldTextParse,
                "recognizedTextParse": recognizedTextParse,
            ])
            try writeReport(rows: rows, fixture: fixture, to: reportURL)
        }
        XCTAssertEqual(rows.count, cases.count)
        print("VOICE_CANDIDATE_REPORT=\(reportURL.path)")
    }

    @MainActor
    private func transcribe(
        _ fileURL: URL, locale: Locale, terms: [String], engine: String, hints: Bool
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
                    fileURL: fileURL, locale: locale, contextualStrings: terms, useHints: hints
                )
            case "sfSpeechRecognizer":
                result = try await DSpeechFileRecognizerSFSpeechRecognizer().transcribe(
                    fileURL: fileURL, locale: locale, contextualStrings: terms, useHints: hints
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
                "elapsedSeconds": Date().timeIntervalSince(started),
            ]
        } catch {
            return [
                "status": "failed",
                "reason": String(describing: error),
                "elapsedSeconds": Date().timeIntervalSince(started),
            ]
        }
    }

    @MainActor
    private func parse(
        _ request: DictationParseRequest, factory: DExaminationNeuralModelFactory,
        forcedMLX: DExaminationNeuralModelMLX?
    ) async -> [String: Any] {
        let started = Date()
        do {
            let proposal: DictationProposal
            if let forcedMLX {
                proposal = try await forcedMLX.parseProposals(request: request)
            } else {
                proposal = try await factory.parseProposals(request: request)
            }
            let source: String
            switch proposal.source {
            case .labeledDictation:
                source = "labeledDictation"
            case .explicitFacts:
                source = "explicitFacts"
            case .localModel:
                source = "localModel"
            case .serverModel:
                source = "serverModel"
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            var fields: [String: Any] = [:]
            var quotes: [String: String] = [:]
            var warnings: [String: [String]] = [:]
            for item in proposal.proposals {
                let value: Any
                switch item.value {
                case let .text(text): value = text
                case let .gender(gender): value = gender.rawValue
                case let .date(date): value = formatter.string(from: date)
                case let .number(number): value = number
                }
                fields[item.id.rawValue] = value
                quotes[item.id.rawValue] = item.sourceQuote
                warnings[item.id.rawValue] = item.warnings.map(\.rawValue)
            }
            return [
                "status": "ok",
                "source": source,
                "fields": fields,
                "sourceQuotes": quotes,
                "warnings": warnings,
                "unmappedFindings": proposal.unmappedFindings,
                "rejectedFieldIds": proposal.rejectedFieldIds.map(\.rawValue),
                "elapsedSeconds": Date().timeIntervalSince(started),
            ]
        } catch {
            return [
                "status": "failed",
                "reason": String(describing: error),
                "elapsedSeconds": Date().timeIntervalSince(started),
            ]
        }
    }

    private func reportDestination() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let runID = ProcessInfo.processInfo.environment["VOICE_REPORT_ID"]
        let name = runID.map { "voice-candidate-ios-\($0).json" } ?? "voice-candidate-ios.json"
        return documents.appendingPathComponent(name)
    }

    private func writeReport(rows: [[String: Any]], fixture: [String: Any], to destination: URL) throws {
        let report: [String: Any] = [
            "schemaVersion": 1, "platform": platformName,
            "runId": ProcessInfo.processInfo.environment["VOICE_REPORT_ID"] as Any? ?? NSNull(),
            "systemVersion": UIDevice.current.systemVersion,
            "deviceModel": UIDevice.current.model,
            "fixtureRegressionSha256": fixture["regressionSha256"] ?? NSNull(),
            "fixtureControlSha256": fixture["controlSha256"] ?? NSNull(),
            "fixtureVoiceBlindSha256": fixture["voiceBlindSha256"] ?? NSNull(),
            "fixtureFreeformDevelopmentSha256": fixture["freeformDevelopmentSha256"] ?? NSNull(),
            "fixtureAdversarialSha256": fixture["adversarialSha256"] ?? NSNull(),
            "fixtureSplit": fixture["split"] ?? "regression",
            "fixtureAudioManifestSha256": fixture["audioManifestSha256"] ?? NSNull(),
            "fixtureAudioMode": fixture["audioMode"] ?? NSNull(),
            "fixtureAudioVariant": fixture["audioVariant"] ?? NSNull(),
            "fixturePromptSha256": fixture["promptSha256"] ?? NSNull(),
            "fixtureContextualStringsSha256": fixture["contextualStringsSha256"] ?? NSNull(),
            "fixtureApplicationSha256": fixture["applicationSha256"] ?? NSNull(),
            "fixtureSourceFilesSha256": fixture["sourceFilesSha256"] ?? NSNull(),
            "fixtureInputSource": fixture["inputSource"] ?? "originalText",
            "forcedMLXDiagnostic": ProcessInfo.processInfo.environment["VOICE_FORCE_MLX"] == "1",
            "fixtureASRRecognizer": fixture["asrRecognizer"] ?? NSNull(),
            "fixtureASRReportSha256": fixture["asrReportSha256"] ?? NSNull(),
            "results": rows,
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: destination, options: .atomic)
    }

    private var platformName: String {
        #if targetEnvironment(simulator)
            "iOS Simulator"
        #else
            "iOS"
        #endif
    }

    private func dictionary(_ value: Any) throws -> [String: Any] {
        try XCTUnwrap(value as? [String: Any])
    }

    private func string(_ dictionary: [String: Any], _ key: String) throws -> String {
        try XCTUnwrap(dictionary[key] as? String)
    }
}
