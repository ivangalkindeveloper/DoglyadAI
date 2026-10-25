import Combine
@testable import Doglyad
import DoglyadSpeech
@testable import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ModuleInputLimitTests {
    @Test
    func scanUsesConfiguredLimitsForEveryTextController() throws {
        let container = try makeContainer()
        let model = makeScanModel(
            container: container,
        )
        for inputTextController in [
            model.examinationNumberTextController,
            model.patientNameTextController,
            model.patientHeightCMTextController,
            model.patientWeightKGTextController,
            model.patientComplaintsTextController,
            model.examinationDescriptionTextController,
        ] {
            inputTextController.setText(
                "123456",
            )
            #expect(
                inputTextController.text == "1234",
            )
        }
    }

    @Test
    func loadingLongDraftRetainsEveryFieldInAutosaveSnapshots() throws {
        let container = try makeContainer()
        let model = makeScanModel(
            container: container,
        )
        let form = USExaminationDraftForm(
            examinationNumber: "123456",
            patientName: "Original patient name",
            patientGender: .female,
            patientDateOfBirth: Date(
                timeIntervalSince1970: 0,
            ),
            patientHeightCM: "180.25",
            patientWeightKG: "80.125",
            patientComplaints: "Original complaints",
            examinationDescription: "Original examination description",
        )
        model.applyDraft(
            USExaminationDraft(
                form: form,
                photos: [],
            ),
        )
        #expect(
            model.makeDraftSnapshot() == form,
        )
        #expect(
            model.patientNameTextController.isError,
        )
        #expect(
            model.patientComplaintsTextController.isError,
        )
        #expect(
            model.examinationDescriptionTextController.isError,
        )
        #expect(
            model.focusList.contains { $0.focus == .patientComplaints },
        )
    }

    @Test
    func longDictationRetainsTheSourceAndRequiresEditingBeforeParsing() throws {
        let container = try makeContainer()
        let locale = Locale(
            identifier: "en",
        )
        let speechController = ScanSpeechTestController(
            locale: locale,
            contextualStrings: [],
            lexiconLocalization: VoiceLocalizationTestSupport.speech(
                locale: locale,
            ),
        )
        let source = "Weight 70 kg"
        speechController.lastTranscript = DSpeechTranscript(
            rawText: source,
            correctedText: source,
            locale: locale,
            engine: .whisperKit,
            completion: .finished,
        )
        let model = ScanSpeechViewModel(
            container: container,
            messager: DMessager(),
            router: makeRouter(),
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
        model.onInit()
        #expect(
            model.state is ScanSpeechReviewTranscriptState,
        )
        #expect(
            model.transcriptTextController.text == source,
        )
        #expect(
            model.transcriptTextController.isError,
        )
        model.onTapContinue()
        #expect(
            model.state is ScanSpeechReviewTranscriptState,
        )
        #expect(
            model.originalTranscript?.correctedText == source,
        )
    }

    private func makeContainer() throws -> DependencyContainer {
        let data = try JSONEncoder().encode(
            ApplicationConfig.default,
        )
        var document = try #require(
            JSONSerialization.jsonObject(
                with: data,
            ) as? [String: Any],
        )
        var scan = try #require(
            document[
                "scan",
            ] as? [String: Any],
        )
        for key in scan.keys {
            scan[
                key,
            ] = 4
        }
        document[
            "scan",
        ] = scan
        document[
            "scanSpeech",
        ] = ["transcriptMaxLength": 4]
        let configuration = try JSONDecoder().decode(
            ApplicationConfig.self,
            from: JSONSerialization.data(
                withJSONObject: document,
            ),
        )
        return makeStateTestContainer(
            reportRepository: StateReportRepository(),
            draftRepository: StateDraftRepository(),
            applicationConfig: configuration,
        )
    }

    private func makeScanModel(
        container: DependencyContainer,
    ) -> ScanViewModel {
        ScanViewModel(
            container: container,
            messager: DMessager(),
            router: makeRouter(),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getSettingsAI: { container.initialSettingsAI },
            onRequestCountIncremented: {},
            observeExaminationChanges: { _ in AnyCancellable {} },
            getSelectedTemplate: { nil },
            onTemplateSelected: { _ in },
            onTemplateReset: {},
            getNeuralModel: { container.usExaminationNeuralModelDefault },
            onNeuralModelSelected: { _ in },
        )
    }

    private func makeRouter() -> DRouter {
        DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
    }
}
