import Combine
@testable import Doglyad
import DoglyadSpeech
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ScanSpeechObservationTests {
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
        let observation = model.objectWillChange.sink { changes += 1 }
        let phaseObservation = model.$state.dropFirst().sink { _ in phaseChanges += 1 }
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
        let observation = model.objectWillChange.sink { changes += 1 }
        defer { observation.cancel() }

        speechController.text = "Late result"
        speechController.audioMeter = 1
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        #expect(
            changes == 0,
        )
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
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: { container.initialSettingsAI },
            onRequestCountIncremented: {},
            arguments: ScanSpeechArguments(
                examinationType: container.usExaminationTypeDefault,
                onConfirm: { _ in true },
            ),
            speechController: speechController,
        )
    }
}
