import AVFoundation
@testable import Doglyad
@testable import DoglyadSpeech
import Foundation
import Testing

@MainActor
struct TOneSpeechTests {
    init() {}

    @Test
    func retryUploadsTheSameRecordingWithoutStartingMicrophoneAgain() async throws {
        let capture = TOneTestAudioCapture()
        var uploads: [Data] = []
        let controller = makeController(
            capture: capture,
        ) { audio in
            uploads.append(
                audio,
            )
            if uploads.count == 1 {
                throw URLError(
                    .notConnectedToInternet,
                )
            }
            return "вес семьдесят два килограмма"
        }
        controller.start()
        let first = await controller.stop()
        #expect(
            first?.completion == .failed,
        )
        #expect(
            controller.isTranscriptionRetryAvailable,
        )
        let retry = await controller.stop()
        #expect(
            retry?.rawText == "вес семьдесят два килограмма",
        )
        #expect(
            retry?.engine == .tOne,
        )
        #expect(
            retry?.confidenceSpans.isEmpty == true,
        )
        #expect(
            !controller.isTranscriptionRetryAvailable,
        )
        #expect(
            capture.startCount == 1,
        )
        #expect(
            capture.stopCount == 1,
        )
        #expect(
            uploads == [capture.audio, capture.audio],
        )
        let repeatedStop = await controller.stop()
        #expect(
            repeatedStop?.rawText == retry?.rawText,
        )
        #expect(
            uploads.count == 2,
        )
    }

    @Test
    func cancellationDiscardsRecordingAndLateResponse() async throws {
        let capture = TOneTestAudioCapture()
        var continuation: CheckedContinuation<String, Never>?
        let controller = makeController(
            capture: capture,
        ) { _ in
            await withCheckedContinuation {
                continuation = $0
            }
        }
        controller.start()
        let task = Task {
            await controller.stop()
        }
        for _ in 0 ..< 100 {
            if continuation != nil {
                break
            }
            await Task.yield()
        }
        let response = try #require(
            continuation,
        )
        _ = controller.cancel()
        response.resume(
            returning: "late response",
        )
        #expect(
            await task.value == nil,
        )
        #expect(
            controller.lastTranscript == nil,
        )
        #expect(
            controller.text == nil,
        )
        #expect(
            !controller.isTranscriptionRetryAvailable,
        )
        #expect(
            controller.recordingStatus == .stopped,
        )
    }

    @Test
    func factoryRequiresRussianAndAnExplicitTransport() async throws {
        let locale = Locale(
            identifier: "ru",
        )
        let localization = VoiceLocalizationTestSupport.speech(
            locale: locale,
        )
        await #expect(
            throws: DSpeechError.self,
        ) {
            try await DSpeechFactory.make(
                engine: .tOne,
                locale: locale,
                contextualStrings: [],
                lexiconLocalization: localization,
            )
        }
        let controller = try await DSpeechFactory.make(
            engine: .tOne,
            locale: locale,
            contextualStrings: [],
            lexiconLocalization: localization,
            transcribeAudio: { _ in
                "test"
            },
        )
        #expect(
            controller is DSpeechControllerTOne,
        )
        await #expect(
            throws: DSpeechError.self,
        ) {
            try await DSpeechFactory.make(
                engine: .tOne,
                locale: Locale(
                    identifier: "en",
                ),
                contextualStrings: [],
                lexiconLocalization: localization,
                transcribeAudio: { _ in
                    "test"
                },
            )
        }
    }

    @Test
    func audioCategorySetupDoesNotInterruptRecordingButDeviceRemovalDoes() async throws {
        let capture = TOneTestAudioCapture()
        let controller = makeController(
            capture: capture,
        ) { _ in
            "вес семьдесят два"
        }
        controller.start()
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.categoryChange.rawValue],
        )
        await Task.yield()
        #expect(
            controller.recordingStatus == .recording,
        )
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue],
        )
        for _ in 0 ..< 100 {
            if controller.lastTranscript != nil {
                break
            }
            await Task.yield()
        }
        #expect(
            controller.lastTranscript?.completion == .interrupted,
        )
        #expect(
            capture.stopCount == 1,
        )
        _ = controller.cancel()
    }

    private func makeController(
        capture: TOneTestAudioCapture,
        transcribe: @escaping @MainActor (Data) async throws -> String,
    ) -> DSpeechControllerTOne {
        let locale = Locale(
            identifier: "ru",
        )
        return DSpeechControllerTOne(
            locale: locale,
            transcribe: transcribe,
            makeCapture: { _, _ in
                capture
            },
        )
    }
}
