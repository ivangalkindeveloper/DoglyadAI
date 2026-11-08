#if DEBUG && DOGLYAD_REGRESSION
    import Combine
    @testable import Doglyad
    @testable import DoglyadUI
    import Router
    import XCTest

    @MainActor
    final class ScanSpeechRegressionTests: XCTestCase {
        func testRecordingRejectsDuplicateActionsAndLateTranscript() async throws {
            let (model, controller) = makeModel()
            model.onInit()
            model.onTapSpeech()
            XCTAssertNil(
                model.originalTranscript,
            )
            try await waitUntil {
                model.state is ScanSpeechReadyState
            }
            model.onTapSpeech()
            XCTAssertTrue(
                model.state is ScanSpeechRecordingState,
            )
            model.onTapSpeech()
            model.onTapSpeech()
            XCTAssertTrue(
                model.state is ScanSpeechTranscriptionLoadingState,
            )
            // Let the asynchronous stop begin, then close before its delayed result.
            try await Task.sleep(
                for: .milliseconds(
                    50,
                ),
            )
            model.onDisappear()
            let closed = model.state
            try await Task.sleep(
                for: .milliseconds(
                    500,
                ),
            )
            XCTAssertTrue(
                model.state === closed,
            )
            XCTAssertNil(
                model.originalTranscript,
            )
            XCTAssertEqual(
                controller.recordingStatus,
                .stopped,
            )
            model.onTapSpeech()
            XCTAssertTrue(
                model.state === closed,
            )
        }

        func testEmptyAndOversizedTranscriptCannotStartParsing() async throws {
            let (model, _) = makeModel()
            model.onInit()
            try await waitUntil {
                model.state is ScanSpeechReadyState
            }
            model.onTapSpeech()
            model.onTapSpeech()
            try await waitUntil {
                model.state is ScanSpeechReviewTranscriptState
            }
            XCTAssertNotNil(
                model.originalTranscript,
            )
            XCTAssertNil(
                model.textForParsing,
            )
            let review = model.state
            model.onTapContinue()
            XCTAssertTrue(
                model.state === review,
            )
            model.transcriptTextController.setText(
                " \n ",
            )
            XCTAssertNil(
                model.textForParsing,
            )
            model.onTapContinue()
            XCTAssertTrue(
                model.state === review,
            )
            let maximum = DependencyContainer.previewable.applicationConfig.scanSpeech.transcriptMaxLength
            model.transcriptTextController.restoreText(
                String(
                    repeating: "a",
                    count: maximum + 1,
                ),
            )
            XCTAssertFalse(
                model.transcriptTextController.validate(),
            )
            model.onTapContinue()
            XCTAssertTrue(
                model.state === review,
                "An oversized restored transcript must not reach the parser",
            )
            model.transcriptTextController.clear()
            model.transcriptTextController.setText(
                String(
                    repeating: "b",
                    count: maximum + 1,
                ),
            )
            XCTAssertLessThanOrEqual(
                model.transcriptTextController.text.count,
                maximum,
            )
            model.transcriptTextController.setText(
                "Edited transcript",
            )
            XCTAssertEqual(
                model.textForParsing,
                "Edited transcript",
            )
            model.onDisappear()
        }

        private func makeModel() -> (ScanSpeechViewModel, RegressionSpeechController) {
            UserDefaults.standard.set(
                "empty",
                forKey: "regressionSpeech",
            )
            defer {
                UserDefaults.standard.removeObject(
                    forKey: "regressionSpeech",
                )
            }
            let container = DependencyContainer.previewable
            let controller = RegressionSpeechController(
                locale: container.language.currentLocale,
                contextualStrings: [],
                lexiconLocalization: container.l10n.voice.speech,
            )
            let model = ScanSpeechViewModel(
                container: container,
                messager: DMessager(),
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
                arguments: ScanSpeechArguments(
                    examinationType: container.usExaminationTypeDefault,
                    onConfirm: { _ in
                        XCTFail(
                            "Empty, invalid or cancelled transcripts cannot update the form",
                        )
                        return false
                    },
                ),
                speechController: controller,
            )
            return (model, controller)
        }

        private func waitUntil(
            _ predicate: () -> Bool,
        ) async throws {
            for _ in 0 ..< 200 {
                if predicate() {
                    return
                }
                try await Task.sleep(
                    for: .milliseconds(
                        10,
                    ),
                )
            }
            XCTFail(
                "Speech state did not become ready",
            )
        }
    }

#endif
