import FluidAudio
import Foundation
import os
import XCTest

final class VoiceParakeetTests: XCTestCase {
    func testBundledVoiceFiles() async throws {
        guard ProcessInfo.processInfo.environment["VOICE_PARAKEET_RUN"] == "1" else {
            throw XCTSkip("Run with TEST_RUNNER_VOICE_PARAKEET_RUN=1 and prepared VoiceFixtures")
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
        let modelFolder = documents.appendingPathComponent("VoiceParakeetModel", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelFolder.appendingPathComponent("Encoder.mlmodelc").path))

        let availableMemoryBeforeLoad = UInt64(os_proc_available_memory())
        let loadStarted = Date()
        let models = try AsrModels.loadLocal(from: modelFolder, version: .v3)
        let asr = AsrManager(models: models)
        let loadSeconds = Date().timeIntervalSince(loadStarted)
        let availableMemoryAfterLoad = UInt64(os_proc_available_memory())
        var minimumAvailableMemoryAfterTranscription = availableMemoryAfterLoad
        var rows: [[String: Any]] = []
        let runID = ProcessInfo.processInfo.environment["VOICE_REPORT_ID"] ?? "manual"
        let reportURL = documents.appendingPathComponent("voice-parakeet-ios-\(runID).json")

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
                var decoderState = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
                let language: Language = locale == "ru" ? .russian : .english
                let transcription = try await asr.transcribe(
                    audioURL, decoderState: &decoderState, language: language
                )
                result = [
                    "id": id,
                    "locale": locale,
                    "status": "ok",
                    "correctedText": transcription.text.trimmingCharacters(in: .whitespacesAndNewlines),
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
            minimumAvailableMemoryAfterTranscription = min(
                minimumAvailableMemoryAfterTranscription,
                UInt64(os_proc_available_memory())
            )
            let report: [String: Any] = [
                "runId": runID,
                "modelLabel": "parakeet-tdt-0.6b-v3-coreml",
                "modelLoadSeconds": loadSeconds,
                "availableMemoryBeforeLoadBytes": availableMemoryBeforeLoad,
                "availableMemoryAfterLoadBytes": availableMemoryAfterLoad,
                "minimumAvailableMemoryAfterTranscriptionBytes": minimumAvailableMemoryAfterTranscription,
                "fixtureAudioManifestSha256": fixture["audioManifestSha256"] ?? NSNull(),
                "fixtureAudioMode": fixture["audioMode"] ?? NSNull(),
                "fixtureAudioVariant": fixture["audioVariant"] ?? NSNull(),
                "results": rows,
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: reportURL, options: .atomic)
        }
        XCTAssertEqual(rows.count, cases.count)
        print("VOICE_PARAKEET_REPORT=\(reportURL.path)")
    }
}
