import Combine
@testable import Doglyad
import DoglyadNeuralModel
import DoglyadSpeech
import DoglyadUI
import Foundation
import Router
import Testing

@MainActor
struct ScanSpeechAudioTests {
    init() {}

    @Test
    func audioUsesCombinedResponseAndOnlyEditedTextMakesAnotherRequest() async throws {
        let repository = StateReportRepository()
        repository.audioParseResponse = try JSONDecoder().decode(
            USAudioParseResponse.self,
            from: Data(
                #"{"transcript":"Вес 72 кг.","result":{"proposals":[{"fieldId":"patient_weight_kg","value":72,"evidence":"Вес 72 кг","accuracy":"full"}]}}"#.utf8,
            ),
        )
        let base = DependencyContainer.previewable
        let modelConfig = base.applicationConfig.ultrasound.examinationNeuralModel
        let factory = DNeuralUltrasoundModelFactory(
            locale: base.language.currentLocale,
            proposalPrompt: modelConfig.proposalPrompt,
            parameters: DNeuralGenerationParameters(
                temperature: modelConfig.temperature,
                maxTokens: modelConfig.maxTokens,
                maxContextTokens: modelConfig.maxContextTokens,
            ),
            parseTranscript: repository.parseTranscript,
        )
        let container = makeStateTestContainer(
            reportRepository: repository,
            draftRepository: StateDraftRepository(),
            examinationNeuralModelFactory: factory,
        )
        let controller = ScanSpeechTestController(
            locale: container.language.currentLocale,
            contextualStrings: [],
            lexiconLocalization: container.l10n.voice.speech,
        )
        let model = ScanSpeechViewModel(
            container: container,
            speechController: controller,
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
                SettingsAI(
                    transcriberType: .tOne,
                    transcriptParserType: .foundationModels,
                    selectedNeuralModelId: container.usExaminationNeuralModelDefault.id,
                    isMarkdown: false,
                    temperature: nil,
                    maxTokens: nil,
                )
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
        controller.onStop = { [weak model] in
            guard let model, let text = try? await model.parseAudio(
                Data(
                    [0, 0],
                ),
            ) else {
                return nil
            }
            return DSpeechTranscript(
                rawText: text,
                correctedText: text,
                locale: container.language.currentLocale,
                engine: .tOne,
                completion: .finished,
            )
        }
        defer {
            model.onDisappear()
        }
        model.emit(
            ScanSpeechRecordingState(),
        )
        model.onTapSpeech()
        await model.operationTask?.value
        await model.lastTask?.value
        #expect(
            repository.audioParseCount == 1,
        )
        #expect(
            repository.audioModelId == container.usExaminationNeuralModelDefault.id,
        )
        #expect(
            repository.transcriptParseCount == 0,
        )
        #expect(
            model.state is ScanSpeechReviewProposalState,
        )
        model.onTapBackToTranscript()
        model.onTapContinue()
        await model.lastTask?.value
        #expect(
            repository.audioParseCount == 1 && repository.transcriptParseCount == 0,
        )
        model.onTapBackToTranscript()
        model.transcriptTextController.setText(
            "Вес 80 кг.",
        )
        model.onTapContinue()
        await model.lastTask?.value
        #expect(
            repository.audioParseCount == 1 && repository.transcriptParseCount == 1,
        )
        #expect(
            repository.transcriptModelId == container.usExaminationNeuralModelDefault.id,
        )
    }
}
