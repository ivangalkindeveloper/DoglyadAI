import Foundation
import WhisperKit
import XCTest

final class VoiceWhisperKitTests: XCTestCase {
    func testBundledVoiceFiles() async throws {
        guard ProcessInfo.processInfo.environment["VOICE_WHISPERKIT_RUN"] == "1" else {
            throw XCTSkip("Run with TEST_RUNNER_VOICE_WHISPERKIT_RUN=1 and prepared VoiceFixtures")
        }
        let bundle = Bundle(for: Self.self)
        let fixtureURL = try XCTUnwrap(
            bundle.url(forResource: "cases", withExtension: "json", subdirectory: "VoiceFixtures")
                ?? bundle.url(forResource: "cases", withExtension: "json")
        )
        let fixture = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as? [String: Any]
        )
        let cases = try XCTUnwrap(fixture["cases"] as? [[String: Any]])
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelFolder = documents.appendingPathComponent("VoiceWhisperKitModel", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelFolder.appendingPathComponent("AudioEncoder.mlmodelc").path))
        let prewarm = ProcessInfo.processInfo.environment["VOICE_WHISPERKIT_PREWARM"] == "1"

        let loadStarted = Date()
        let model = try await WhisperKit(WhisperKitConfig(
            modelFolder: modelFolder.path,
            tokenizerFolder: modelFolder,
            verbose: false,
            prewarm: prewarm,
            load: true,
            download: false
        ))
        let loadSeconds = Date().timeIntervalSince(loadStarted)
        var rows: [[String: Any]] = []
        let runID = ProcessInfo.processInfo.environment["VOICE_REPORT_ID"] ?? "manual"
        let reportURL = documents.appendingPathComponent("voice-whisperkit-ios-\(runID).json")

        for testCase in cases {
            let id = try XCTUnwrap(testCase["id"] as? String)
            let locale = try XCTUnwrap(testCase["locale"] as? String)
            let audioName = try XCTUnwrap(testCase["audioFile"] as? String)
            let audioURL = try XCTUnwrap(
                bundle.url(forResource: (audioName as NSString).deletingPathExtension,
                           withExtension: "wav", subdirectory: "VoiceFixtures")
                    ?? bundle.url(forResource: (audioName as NSString).deletingPathExtension, withExtension: "wav")
            )
            let started = Date()
            let result: [String: Any]
            do {
                let segments = try await model.transcribe(
                    audioPath: audioURL.path,
                    decodeOptions: DecodingOptions(language: locale)
                )
                result = [
                    "id": id,
                    "locale": locale,
                    "status": "ok",
                    "correctedText": segments.map(\.text).joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    "elapsedSeconds": Date().timeIntervalSince(started),
                ]
            } catch {
                result = [
                    "id": id,
                    "locale": locale,
                    "status": "failed",
                    "reason": String(describing: error),
                    "elapsedSeconds": Date().timeIntervalSince(started),
                ]
            }
            rows.append(result)
            let report: [String: Any] = [
                "runId": runID,
                "prewarm": prewarm,
                "modelLoadSeconds": loadSeconds,
                "fixtureAudioManifestSha256": fixture["audioManifestSha256"] ?? NSNull(),
                "fixtureAudioMode": fixture["audioMode"] ?? NSNull(),
                "fixtureAudioVariant": fixture["audioVariant"] ?? NSNull(),
                "results": rows,
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: reportURL, options: .atomic)
        }
        XCTAssertEqual(rows.count, cases.count)
        print("VOICE_WHISPERKIT_REPORT=\(reportURL.path)")
    }
}
