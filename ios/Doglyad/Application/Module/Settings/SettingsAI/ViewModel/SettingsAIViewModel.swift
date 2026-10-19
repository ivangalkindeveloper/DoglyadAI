import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class SettingsAIViewModel: DModuleViewModel<any SettingsAIStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: SettingsAIFocus?
    @Published var transcriberType: TranscriberType
    @Published var transcriptParserType: TranscriptParserType
    @Published var neuralModel: USExaminationNeuralModel
    @Published var isMarkdown: Bool = false
    @NestedObservableObject var temperatureTextController: DTextFieldController
    @NestedObservableObject var maxTokensTextController: DTextFieldController

    private let getInitialIsMarkdown: () -> Bool
    private let getInitialTemperature: () -> Double
    private let getInitialMaxTokens: () -> Int
    private let messager: DMessager
    private let onNeuralModelSelected: (USExaminationNeuralModel) async throws -> Void
    private let onSettingsSaved: (TranscriberType, TranscriptParserType, Bool, Double?, Int?) async throws -> Void

    init(
        container: DependencyContainer,
        getInitialNeuralModel: @escaping () -> USExaminationNeuralModel,
        getInitialIsMarkdown: @escaping () -> Bool,
        getInitialTemperature: @escaping () -> Double,
        getInitialMaxTokens: @escaping () -> Int,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) async throws -> Void,
        onSettingsSaved: @escaping (TranscriberType, TranscriptParserType, Bool, Double?, Int?) async throws -> Void,
    ) {
        transcriberType = getSettingsAI().transcriberType
        transcriptParserType = getSettingsAI().transcriptParserType
        neuralModel = getInitialNeuralModel()
        self.onNeuralModelSelected = onNeuralModelSelected
        self.getInitialIsMarkdown = getInitialIsMarkdown
        self.getInitialTemperature = getInitialTemperature
        self.getInitialMaxTokens = getInitialMaxTokens
        self.messager = messager
        self.onSettingsSaved = onSettingsSaved

        _temperatureTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldDecimalFormatter(),
                ],
                validators: [
                    DTextFieldDoubleRangeValidator(
                        validRange: 0 ... 2,
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidSettingsAITemperatureDescription,
                            ],
                        ),
                    ),
                ],
            ),
        )
        _maxTokensTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldIntegerFormatter(),
                ],
                validators: [
                    DTextFieldIntRangeValidator(
                        validRange: 1 ... 4096,
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidSettingsAIMaxTokensDescription,
                            ],
                        ),
                    ),
                ],
            ),
        )

        super.init(
            state: SettingsAIDefaultState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .settingsAI,
            ),
        )
        _ = temperatureTextController
        _ = maxTokensTextController
        isMarkdown = getInitialIsMarkdown()
        temperatureTextController.setText(
            String(
                getInitialTemperature(),
            ),
        )
        maxTokensTextController.setText(
            String(
                getInitialMaxTokens(),
            ),
        )
    }

    var isReportGenerationSettingsEnabled: Bool {
        subscriptionStatus?.isReportGenerationSettingsAvailable == true
    }

    var reportGenerationSettingsAvailability: SubscriptionFeatureAvailability {
        isReportGenerationSettingsEnabled ? .available : .offered
    }

    var focusList: [DTextFieldFocusValidationItem<SettingsAIFocus>] {
        guard isReportGenerationSettingsEnabled else { return [] }
        return [
            DTextFieldFocusValidationItem(
                focus: .temperature,
                inputTextController: temperatureTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .length,
                inputTextController: maxTokensTextController,
            ),
        ]
    }

    var isPreviousFieldFocusable: Bool {
        switch focus {
        case .temperature, .none:
            false
        case .length:
            true
        }
    }

    var isNextFieldFocusable: Bool {
        switch focus {
        case .temperature:
            true
        case .length, .none:
            false
        }
    }

    override func onSubscriptionChanged(
        _: SubscriptionStatus?,
    ) {
        if !isReportGenerationSettingsEnabled { unfocus() }
    }

    func onTapTranscriber() {
        unfocus()
        coordinator.sheet(
            .selectTranscriber,
            arguments: SelectTranscriberArguments(
                currentValue: transcriberType,
                onSelected: { [weak self] type in self?.transcriberType = type },
            ),
        )
    }

    func onTapTranscriptParser() {
        unfocus()
        coordinator.sheet(
            .selectTranscriptParser,
            arguments: SelectTranscriptParserArguments(
                currentValue: transcriptParserType,
                onSelected: { [weak self] type in self?.transcriptParserType = type },
            ),
        )
    }

    func onTapNeuralModelSelection() {
        unfocus()
        analytics.buttonTapped(
            .settingsAINeuralModelSelection,
            parameters: AnalyticsParameters(
                [
                    .modelId: .string(
                        neuralModel.id,
                    ),
                ],
            ),
        )
        coordinator.sheet(
            .selectNeuralModel,
            arguments: SelectNeuralModelArguments(
                currentValue: neuralModel,
                onSelected: { [weak self] model in
                    guard let self else { return }
                    guard neuralModel != model else { return }

                    try await onNeuralModelSelected(
                        model,
                    )
                    withAnimation(
                        DTheme.light.animation,
                    ) {
                        self.neuralModel = model
                    }
                },
            ),
        )
    }

    func onFocusChanged(
        _ newFocus: SettingsAIFocus?,
    ) {
        focus = isReportGenerationSettingsEnabled ? newFocus : nil
    }

    func unfocus() {
        focus = nil
    }

    func onTapToolbarUp() {
        switch focus {
        case .temperature, .none:
            break
        case .length:
            focus = .temperature
        }
    }

    func onTapToolbarDown() {
        switch focus {
        case .temperature:
            focus = .length
        case .length, .none:
            break
        }
    }

    func toggleIsMarkdown() {
        guard isReportGenerationSettingsEnabled else { return }
        analytics.buttonTapped(
            .settingsAIMarkdown,
            parameters: AnalyticsParameters(
                [
                    .result: .bool(
                        !isMarkdown,
                    ),
                ],
            ),
        )
        isMarkdown.toggle()
    }

    func onSubmit() {
        analytics.buttonTapped(
            .settingsAISubmit,
        )
        switch focus {
        case .temperature:
            focus = .length
        case .length, .none:
            focus = nil
        }
    }

    func onTapBack() {
        analytics.buttonTapped(
            .settingsAIBack,
        )
        coordinator.pop()
    }

    func onTapSave() {
        switch state {
        case _ as SettingsAILoadingState: return
        default: break
        }

        analytics.buttonTapped(
            .settingsAISave,
            parameters: AnalyticsParameters(
                [
                    .result: .bool(
                        isMarkdown,
                    ),
                ],
            ),
        )

        switch transcriptParserType {
        case .foundationModels:
            guard container.examinationNeuralModelFactory.isFoundationModelsAvailable else {
                onTapTranscriptParser()
                return
            }
        case .server:
            break
        }

        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        unfocus()
        emit(
            SettingsAILoadingState(),
        )

        let isMarkdown = isReportGenerationSettingsEnabled ? isMarkdown : getInitialIsMarkdown()
        let temperature = isReportGenerationSettingsEnabled
            ? temperatureTextController.value.flatMap { Double(
                $0,
            ) } : getInitialTemperature()
        let maxTokens = isReportGenerationSettingsEnabled
            ? maxTokensTextController.value.flatMap { Int(
                $0,
            ) } : getInitialMaxTokens()
        handle {
            try await self.onSettingsSaved(
                self.transcriberType,
                self.transcriptParserType,
                isMarkdown,
                temperature,
                maxTokens,
            )
        } onDefer: {
            switch self.state {
            case _ as SettingsAILoadingState: self.emit(
                    SettingsAIDefaultState(),
                )
            default: break
            }
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .settingsAISavedSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .settingsAISavedSuccessMessageDescription,
                ],
            )
            self.coordinator.pop()
        } onMainUnknownError: { error in
            self.emit(
                SettingsAIFailedState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
