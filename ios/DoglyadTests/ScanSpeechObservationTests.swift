import Combine
@testable import Doglyad
import DoglyadSpeech
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ScanSpeechObservationTests {
    init() {}

    @Test
    func liveTextAndMeterChangesReachTheViewWithoutRepublishingTheRecordingState() async {
        let speechController = makeController()
        speechController.recordingStatus = .recording
        let model = makeModel(
            speechController: speechController,
        )
        let recording = ScanSpeechRecordingState()
        model.emit(
            recording,
        )
        var changes = 0
        var phaseChanges = 0
        let observation = model.objectWillChange.sink {
            changes += 1
        }
        let phaseObservation = model.$state.dropFirst().sink { _ in
            phaseChanges += 1
        }
        defer {
            observation.cancel()
            phaseObservation.cancel()
        }

        speechController.text = "Weight 70 kg"
        speechController.audioMeter = 0.7
        for _ in 0 ..< 50 where changes < 2 {
            await Task.yield()
        }

        #expect(
            changes == 2,
        )
        #expect(
            phaseChanges == 0,
        )
        #expect(
            model.state === recording,
        )
        #expect(
            model.speechController?.text == "Weight 70 kg",
        )
        #expect(
            model.speechController?.audioMeter == 0.7,
        )
    }

    @Test
    func dismissedPresentationIgnoresLateControllerChanges() async {
        let speechController = makeController()
        let model = makeModel(
            speechController: speechController,
        )
        model.onDisappear()
        var changes = 0
        let observation = model.objectWillChange.sink {
            changes += 1
        }
        defer {
            observation.cancel()
        }

        speechController.text = "Late result"
        speechController.audioMeter = 1
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            changes == 0,
        )
    }

    @Test
    func closingCancelsPendingTranscriptionBeforeTheDisappearEvent() async {
        let controller = makeController()
        controller.recordingStatus = .recording
        var response: CheckedContinuation<DSpeechTranscript?, Never>?
        controller.onStop = {
            await withCheckedContinuation {
                response = $0
            }
        }
        let model = makeModel(
            speechController: controller,
        )
        model.emit(
            ScanSpeechRecordingState(),
        )
        model.onTapSpeech()
        while response == nil {
            await Task.yield()
        }
        let task = model.operationTask
        model.onTapBack()
        var changes = 0
        let observation = model.$state.dropFirst().sink { _ in
            changes += 1
        }
        defer {
            observation.cancel()
        }
        response?.resume(
            returning: nil,
        )
        await task?.value
        controller.text = "Late result"
        for _ in 0 ..< 30 {
            await Task.yield()
        }
        #expect(
            changes == 0 && task?.isCancelled == true && model.operationTask == nil,
        )
        model.onDisappear()
    }

    private func makeController() -> ScanSpeechTestController {
        ScanSpeechTestController(
            locale: Locale(
                identifier: "en",
            ),
            contextualStrings: [],
            lexiconLocalization: VoiceLocalizationTestSupport.speech(
                locale: Locale(
                    identifier: "en",
                ),
            ),
        )
    }

    private func makeModel(
        speechController: any DSpeechControllerProtocol,
    ) -> ScanSpeechViewModel {
        let container = DependencyContainer.previewable
        return ScanSpeechViewModel(
            container: container,
            speechController: speechController,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: {
                nil
            },
            observeSubscriptionStatus: { _ in
                AnyCancellable {}
            },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: {
                container.initialSettingsAI
            },
            onRefreshSubscriptionStatus: {},
            messager: DMessager(),
            arguments: ScanSpeechArguments(
                examinationType: container.usExaminationTypeDefault,
                onConfirm: { _ in
                    true
                },
            ),
        )
    }
}
