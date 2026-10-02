import CryptoKit
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import UIKit
import XCTest

final class VoiceBaselineTests: XCTestCase {
    @MainActor
    func testVoiceBaseline() async throws {
        guard ProcessInfo.processInfo.environment["VOICE_BASELINE_RUN"] == "1" else {
            throw XCTSkip("Run with TEST_RUNNER_VOICE_BASELINE_RUN=1 and prepared VoiceFixtures")
        }

        let bundle = Bundle(for: Self.self)
        guard let fixtureURL = bundle.url(forResource: "cases", withExtension: "json", subdirectory: "VoiceFixtures")
            ?? bundle.url(forResource: "cases", withExtension: "json")
        else {
            XCTFail("VoiceFixtures/cases.json is missing from the test bundle")
            return
        }
        let fixture = try requireDictionary(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)))
        guard let cases = fixture["cases"] as? [[String: Any]], !cases.isEmpty,
              let generation = fixture["generation"] as? [String: Any],
              let temperature = generation["temperature"] as? Double,
              let maxTokens = generation["maxTokens"] as? Int,
              let maxContextTokens = generation["maxContextTokens"] as? Int
        else {
            XCTFail("Voice fixture is incomplete")
            return
        }

        let parameters = DExaminationGenerationParameters(
            temperature: temperature,
            maxTokens: maxTokens,
            maxContextTokens: maxContextTokens
        )
        var activeFactory: DExaminationNeuralModelFactory?
        var activeCode: String?
        var rows: [[String: Any]] = []
        let reportURL = try reportDestination()

        for testCase in cases {
            let id = try requireString(testCase, "id")
            let code = try requireString(testCase, "locale")
            let prompt = try requireString(testCase, "systemPrompt")
            let spokenText = try requireString(testCase, "spokenText")
            let audioFile = try requireString(testCase, "audioFile")
            let audioSha256 = try requireString(testCase, "audioSha256")
            guard let contextualStrings = testCase["contextualStrings"] as? [String] else {
                XCTFail("Missing contextual strings for \(id)")
                return
            }
            let locale = Locale(identifier: code == "ru" ? "ru_RU" : "en_US")
            if activeCode != code {
                activeFactory?.unload()
                activeFactory = nil
                activeCode = code
            }
            if activeFactory == nil {
                activeFactory = DExaminationNeuralModelFactory(
                    locale: locale,
                    systemPrompt: prompt,
                    parameters: parameters
                )
            }
            let factory = try XCTUnwrap(activeFactory)

            var row: [String: Any] = try [
                "id": id,
                "locale": code,
                "examinationTypeId": requireString(testCase, "examinationTypeId"),
                "examinationNumberStatus": "unsupported",
            ]
            let audioURL = bundle.url(forResource: (audioFile as NSString).deletingPathExtension,
                                      withExtension: "wav", subdirectory: "VoiceFixtures")
                ?? bundle.url(forResource: (audioFile as NSString).deletingPathExtension, withExtension: "wav")
            if let audioURL {
                let actualHash = try SHA256.hash(data: Data(contentsOf: audioURL))
                    .map { String(format: "%02x", $0) }.joined()
                if actualHash == audioSha256 {
                    row["asr"] = await transcribe(fileURL: audioURL, locale: locale, contextualStrings: contextualStrings)
                } else {
                    row["asr"] = ["status": "failed", "reason": "Bundled WAV hash mismatch"]
                }
            } else {
                row["asr"] = ["status": "failed", "reason": "Bundled WAV is missing"]
            }

            if fixture["measureGold"] as? Bool == false {
                row["goldTextParse"] = ["status": "skipped", "reason": "Repeated gold-text parse disabled for audio run"]
            } else {
                row["goldTextParse"] = await parse(spokenText, factory: factory)
            }
            if let asr = row["asr"] as? [String: Any],
               asr["status"] as? String == "ok",
               let correctedText = asr["correctedText"] as? String,
               !correctedText.isEmpty
            {
                row["recognizedTextParse"] = await parse(correctedText, factory: factory)
            } else {
                row["recognizedTextParse"] = ["status": "skipped", "reason": "No final corrected transcript"]
            }
            rows.append(row)
            try writeReport(rows: rows, fixture: fixture, to: reportURL)
        }
        XCTAssertEqual(rows.count, cases.count)
        print("VOICE_BASELINE_REPORT=\(reportURL.path)")
    }

    @MainActor
    private func transcribe(
        fileURL: URL,
        locale: Locale,
        contextualStrings: [String]
    ) async -> [String: Any] {
        guard #available(iOS 26.0, *) else {
            return ["status": "skipped", "reason": "SpeechAnalyzer requires iOS 26"]
        }
        let started = Date()
        do {
            let result = try await DSpeechFileTranscriber().transcribe(
                fileURL: fileURL,
                locale: locale,
                contextualStrings: contextualStrings
            )
            return [
                "status": "ok",
                "rawText": result.rawText,
                "correctedText": result.correctedText,
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
        _ text: String,
        factory: DExaminationNeuralModelFactory
    ) async -> [String: Any] {
        guard factory.isAvailable else {
            return ["status": "skipped", "reason": "Current local model is unavailable on this device"]
        }
        let started = Date()
        do {
            let response = try await factory.model().parseSpeech(speech: text)
            return [
                "status": "ok",
                "fields": responseFields(response),
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

    private func responseFields(_ response: DExaminationNeuralModelResponse) -> [String: Any] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return [
            "patientName": response.patientName as Any? ?? NSNull(),
            "patientGender": response.patientGender?.rawValue as Any? ?? NSNull(),
            "patientDateOfBirth": response.patientDateOfBirth.map(formatter.string(from:)) as Any? ?? NSNull(),
            "patientHeightCM": response.patientHeightCM as Any? ?? NSNull(),
            "patientWeightKG": response.patientWeightKG as Any? ?? NSNull(),
            "patientComplaints": response.patientComplaints as Any? ?? NSNull(),
            "examinationDescription": response.examinationDescription as Any? ?? NSNull(),
        ]
    }

    private func reportDestination() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let runID = ProcessInfo.processInfo.environment["VOICE_REPORT_ID"]
        let name = runID.map { "voice-baseline-ios-\($0).json" } ?? "voice-baseline-ios.json"
        return documents.appendingPathComponent(name)
    }

    private func writeReport(rows: [[String: Any]], fixture: [String: Any], to destination: URL) throws {
        let report: [String: Any] = [
            "schemaVersion": 1,
            "platform": platformName,
            "runId": ProcessInfo.processInfo.environment["VOICE_REPORT_ID"] as Any? ?? NSNull(),
            "systemVersion": UIDevice.current.systemVersion,
            "deviceModel": UIDevice.current.model,
            "fixtureRegressionSha256": fixture["regressionSha256"] ?? NSNull(),
            "fixtureAudioManifestSha256": fixture["audioManifestSha256"] ?? NSNull(),
            "fixtureAudioMode": fixture["audioMode"] ?? NSNull(),
            "fixtureAudioVariant": fixture["audioVariant"] ?? NSNull(),
            "fixturePromptSha256": fixture["promptSha256"] ?? NSNull(),
            "fixtureContextualStringsSha256": fixture["contextualStringsSha256"] ?? NSNull(),
            "fixtureApplicationSha256": fixture["applicationSha256"] ?? NSNull(),
            "fixtureSourceFilesSha256": fixture["sourceFilesSha256"] ?? NSNull(),
            "results": rows,
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: destination, options: .atomic)
    }

    private var platformName: String {
        #if targetEnvironment(simulator)
            "iOS Simulator"
        #else
            "iOS"
        #endif
    }

    private func requireDictionary(_ value: Any) throws -> [String: Any] {
        guard let dictionary = value as? [String: Any] else {
            throw NSError(domain: "VoiceBaseline", code: 1)
        }
        return dictionary
    }

    private func requireString(_ dictionary: [String: Any], _ key: String) throws -> String {
        guard let value = dictionary[key] as? String else {
            throw NSError(domain: "VoiceBaseline", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing \(key)"])
        }
        return value
    }
}
