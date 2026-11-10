import Combine
import DoglyadNeuralModel
import DoglyadSpeech
import DoglyadUI
import Foundation
import NestedObservableObject
import SwiftUI

@MainActor
final class ScanSpeechViewModel: DModuleViewModel<any ScanSpeechStateProtocol> {
    @NestedObservableObject var transcriptTextController: DTextFieldController
    private(set) var originalTranscript: DSpeechTranscript?
    @Published private(set) var speechController: (any DSpeechControllerProtocol)?
    @Published var automaticFieldIds = Set<DNeuralUltrasoundVoiceFieldId>()
    private let messager: DMessager
    private let arguments: ScanSpeechArguments
    private var speechCancellable: AnyCancellable?
    private var isPresentationActive = true

    init(
        container: DependencyContainer,
        speechController: (any DSpeechControllerProtocol)? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        messager: DMessager,
        arguments: ScanSpeechArguments,
    ) {
        _transcriptTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scanSpeech.transcriptMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scanSpeech.transcriptMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scanSpeech.transcriptMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        #if DEBUG && DOGLYAD_REGRESSION
            let speechController = speechController ?? RegressionSpeechController.make(
                container: container,
            )
        #endif
        self.speechController = speechController
        self.messager = messager
        self.arguments = arguments

        super.init(
            state: ScanSpeechModelLoadingState(
                preparation: .checking,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .bottomSheet(
                .scanSpeech,
            ),
        )
        observeSpeechController()
    }

    var textForParsing: String? {
        guard let originalTranscript else {
            return nil
        }
        let visibleText = transcriptTextController.text
        // Trimming only controls availability; preserve the editor text for parsing.
        let trimmed = visibleText.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        guard !trimmed.isEmpty else {
            return nil
        }

        switch originalTranscript.completion {
        case .finished, .timedOut, .interrupted, .failed:
            return visibleText
        case .cancelled:
            return nil
        }
    }

    var transcriptStatusDescription: LocalizedStringResource {
        guard let originalTranscript else {
            return l10n[
                .scanSpeechReviewFinishedDescription,
            ]
        }
        switch originalTranscript.completion {
        case .finished:
            return l10n[
                .scanSpeechReviewFinishedDescription,
            ]
        case .timedOut:
            return l10n[
                .scanSpeechReviewTimedOutDescription,
            ]
        case .interrupted:
            return l10n[
                .scanSpeechReviewInterruptedDescription,
            ]
        case .failed:
            return l10n[
                .scanSpeechReviewFailedDescription,
            ]
        case .cancelled:
            return l10n[
                .scanSpeechReviewCancelledDescription,
            ]
        }
    }

    var proposalInstructions: LocalizedStringResource {
        automaticFieldIds.isEmpty ? l10n[
            .scanSpeechProposalInstructionsDescription,
        ] : l10n[
            .scanSpeechProposalInstructionsWithAutomaticDescription,
        ]
    }

    private var isFoundationModels: Bool {
        switch settingsAI.transcriptParserType {
        case .foundationModels:
            true
        case .server:
            false
        }
    }

    #if DEBUG
        func configureTranscriptPreview(
            transcript: DSpeechTranscript,
            state: any ScanSpeechStateProtocol,
        ) {
            originalTranscript = transcript
            transcriptTextController.restoreText(
                transcript.correctedText,
            )
            preparePreview(
                state: state,
            )
        }
    #endif

    override func onInit() {
        if let speechController {
            speechController.prepareModel()
            refreshSpeechState()
            return
        }
        let engine = settingsAI.transcriberType.speechEngine
        emit(
            ScanSpeechModelLoadingState(
                preparation: .checking,
            ),
        )
        handle {
            try await DSpeechFactory.make(
                engine: engine,
                locale: self.container.language.currentLocale,
                contextualStrings: self.arguments.examinationType.contextualStrings,
                lexiconLocalization: self.l10n.voice.speech,
            )
        } onMainSuccess: { controller in
            guard !Task.isCancelled, self.isPresentationActive else {
                return
            }
            self.speechController = controller
            self.observeSpeechController()
            controller.prepareModel()
            self.refreshSpeechState()
        } onMainUnknownError: { _ in
            guard !Task.isCancelled, self.isPresentationActive else {
                return
            }
            self.emit(
                ScanSpeechModelPreparationErrorState(),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    override func onDisappear() {
        super.onDisappear()
        isPresentationActive = false
        cancelLastTask()
        speechController?.cancel()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .speechBack,
        )
        if automaticFieldIds.isEmpty {
            analytics.actionCompleted(
                .voiceFlowCancelled,
            )
        }
        isPresentationActive = false
        coordinator.dismissSheet()
    }

    func onTapRetryModelPreparation() {
        guard isPresentationActive else {
            return
        }
        guard let speechController else {
            onInit()
            return
        }
        speechController.prepareModel()
        refreshSpeechState()
    }

    func onTapSpeech() {
        guard isPresentationActive, let speechController else {
            return
        }
        switch state {
        case _ as ScanSpeechReadyState:
            analytics.buttonTapped(
                .speechToggle,
                parameters: .speechToggle(
                    recordingStatus: speechController.recordingStatus,
                ),
            )
            speechController.start()
            container.examinationNeuralModelFactory.prewarm(
                isFoundationModels: isFoundationModels,
            )
            refreshSpeechState()
        case _ as ScanSpeechRecordingState:
            analytics.buttonTapped(
                .speechToggle,
                parameters: .speechToggle(
                    recordingStatus: speechController.recordingStatus,
                ),
            )
            stopSpeech()
        default: break
        }
    }

    func onTapRecordAgain() {
        guard isPresentationActive else {
            return
        }
        switch state {
        case _ as ScanSpeechReviewTranscriptState: break
        default: return
        }

        guard let speechController else {
            return
        }
        speechController.start()
        switch speechController.recordingStatus {
        case .preparing, .recording, .transcribing:
            emit(
                ScanSpeechReadyState(),
            )
            container.examinationNeuralModelFactory.prewarm(
                isFoundationModels: isFoundationModels,
            )
            refreshSpeechState()
        case .stopped: break
        }
    }

    func onTapContinue() {
        guard isPresentationActive else {
            return
        }
        switch state {
        case _ as ScanSpeechReviewTranscriptState:
            guard transcriptTextController.validate() else {
                return
            }
            guard let speech = textForParsing, let originalTranscript else {
                return
            }
            if speech != originalTranscript.correctedText {
                analytics.actionCompleted(
                    .voiceTranscriptEdited,
                )
            }
            let parsing = ScanSpeechReviewParsingLoadingState(
                parsedText: speech,
            )
            emit(
                parsing,
            )
            parseProposals(
                parsing,
                parsedText: parsing.parsedText,
            )
        default: break
        }
    }

    func onTapProposal(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) {
        guard isPresentationActive else {
            return
        }
        switch state {
        case let state as ScanSpeechReviewProposalState:
            emit(
                ScanSpeechReviewProposalState(
                    proposal: state.proposal,
                    reviewProposals: state.reviewProposals,
                    selectedFieldIds: state.selectedFieldIds.symmetricDifference(
                        [id],
                    ),
                ),
            )
        default: break
        }
    }

    func onTapBackToTranscript() {
        guard isPresentationActive else {
            return
        }
        switch state {
        case _ as ScanSpeechReviewProposalState:
            showTranscriptReview()
        default: break
        }
    }

    func onTapApplySelected() {
        guard isPresentationActive else {
            return
        }
        switch state {
        case let state as ScanSpeechReviewProposalState:
            guard !state.selectedFieldIds.isEmpty else {
                return
            }
            let selected = state.reviewProposals.filter {
                state.selectedFieldIds.contains(
                    $0.id,
                )
            }
            guard arguments.onConfirm?(
                selected,
            ) == true else {
                messager.showUnknownError(
                    l10n: l10n,
                )
                return
            }
            analytics.actionCompleted(
                .voiceProposalApplied,
                parameters: .voiceProposalApplied(
                    proposals: selected,
                    source: .reviewed,
                ),
            )
            isPresentationActive = false
            coordinator.dismissSheet()
        default: break
        }
    }

    func fieldTitle(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) -> LocalizedStringResource {
        switch id {
        case .examinationNumber:
            container.l10n[
                .scanExaminationNumberLabel,
            ]
        case .patientName:
            container.l10n[
                .scanPatientNameLabel,
            ]
        case .patientGender:
            container.l10n[
                .scanPatientGenderLabel,
            ]
        case .patientDateOfBirth:
            container.l10n[
                .scanPatientDateOfBirthLabel,
            ]
        case .patientHeightCM:
            container.l10n[
                .scanPatientHeightCMLabel,
            ]
        case .patientWeightKG:
            container.l10n[
                .scanPatientWeightKGLabel,
            ]
        case .patientComplaints:
            container.l10n[
                .scanPatientComplaintsLabel,
            ]
        case .examinationDescription:
            container.l10n[
                .scanExaminationDescriptionLabel,
            ]
        case .isPatientPreparedForExamination:
            container.l10n[
                .scanPatientPreparedForExaminationLabel,
            ]
        }
    }

    func warningText(
        _ warning: DNeuralVoiceProposalWarning,
    ) -> LocalizedStringResource {
        switch warning {
        case .ambiguousDictation:
            container.l10n[
                .scanSpeechProposalWarningAmbiguousDescription,
            ]
        case .sideMismatch:
            container.l10n[
                .scanSpeechProposalWarningSideDescription,
            ]
        case .negationMismatch:
            container.l10n[
                .scanSpeechProposalWarningNegationDescription,
            ]
        case .numberMismatch:
            container.l10n[
                .scanSpeechProposalWarningNumberDescription,
            ]
        case .unitMismatch:
            container.l10n[
                .scanSpeechProposalWarningUnitDescription,
            ]
        case .dateUnverified:
            container.l10n[
                .scanSpeechProposalWarningDateDescription,
            ]
        case .genderUnverified:
            container.l10n[
                .scanSpeechProposalWarningGenderDescription,
            ]
        case .identifierMismatch:
            container.l10n[
                .scanSpeechProposalWarningIdentifierDescription,
            ]
        case .textChanged:
            container.l10n[
                .scanSpeechProposalWarningTextChangedDescription,
            ]
        }
    }

    func proposedValue(
        _ value: DNeuralVoiceFieldValue,
    ) -> String {
        switch value {
        case let .boolean(
            isReady,
        ):
            String(
                localized: container.l10n[
                    isReady ? .scanPatientPreparedLabel : .scanPatientUnpreparedLabel,
                ],
            )
        case let .text(
            text,
        ): text
        case let .gender(
            gender,
        ):
            switch gender {
            case .male:
                String(
                    localized: container.l10n[
                        .scanGenderMaleLabel,
                    ],
                )
            case .female:
                String(
                    localized: container.l10n[
                        .scanGenderFemaleLabel,
                    ],
                )
            }
        case let .date(
            date,
        ):
            date.formatted(
                Date.FormatStyle(
                    date: .abbreviated,
                    time: .omitted,
                ).locale(
                    l10n.locale,
                ),
            )
        case let .number(
            number,
        ):
            String(
                number,
            )
        }
    }

    private func observeSpeechController() {
        speechCancellable?.cancel()
        guard let speechController else {
            return
        }
        speechCancellable = speechController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, isPresentationActive else {
                    return
                }
                objectWillChange.send()
                refreshSpeechState()
            }
        }
    }

    private func refreshSpeechState() {
        guard isPresentationActive else {
            return
        }
        switch state {
        case let transcription as ScanSpeechTranscriptionLoadingState where transcription.parsedText != nil: return
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingLoadingState, _ as ScanSpeechReviewProposalState: return
        default: break
        }

        let next: any ScanSpeechStateProtocol
        guard let speechController else {
            return
        }
        switch speechController.modelPreparationStatus {
        case .checking, .downloading, .loading:
            next = ScanSpeechModelLoadingState(
                preparation: speechController.modelPreparationStatus,
            )
        case .failed:
            switch state {
            case _ as ScanSpeechModelPreparationErrorState: break
            default:
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
            next = ScanSpeechModelPreparationErrorState()
        case .ready:
            switch speechController.recordingStatus {
            case .preparing: next = ScanSpeechRecordingPreparationLoadingState()
            case .recording: next = ScanSpeechRecordingState()
            case .transcribing: next = ScanSpeechTranscriptionLoadingState()
            case .stopped:
                if let transcript = speechController.lastTranscript {
                    processTranscript(
                        transcript,
                    )
                    return
                }
                next = ScanSpeechReadyState()
            }
        }
        emit(
            next,
        )
    }

    private func stopSpeech() {
        guard let speechController else {
            return
        }
        emit(
            ScanSpeechTranscriptionLoadingState(),
        )
        Task { [weak self] in
            let transcript = await speechController.stop()
            guard let self, isPresentationActive else {
                return
            }
            switch state {
            case let transcription as ScanSpeechTranscriptionLoadingState where transcription.parsedText != nil: return
            case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingLoadingState, _ as ScanSpeechReviewProposalState: return
            default: break
            }
            guard let transcript else {
                emit(
                    ScanSpeechReadyState(),
                )
                return
            }
            processTranscript(
                transcript,
            )
        }
    }

    private func processTranscript(
        _ original: DSpeechTranscript,
    ) {
        if original.completion == .failed {
            messager.showUnknownError(
                l10n: l10n,
            )
        }
        originalTranscript = original
        transcriptTextController.restoreText(
            original.correctedText,
        )
        guard original.isReadyForParsing, transcriptTextController.validate() else {
            showTranscriptReview()
            return
        }
        let parsing = ScanSpeechTranscriptionLoadingState(
            parsedText: transcriptTextController.text,
        )
        emit(
            parsing,
        )
        parseProposals(
            parsing,
            parsedText: transcriptTextController.text,
        )
    }

    private func showTranscriptReview() {
        emit(
            ScanSpeechReviewTranscriptState(),
        )
        analytics.actionCompleted(
            .voiceDictationReviewed,
            parameters: .dictationReviewed(
                completion: originalTranscript?.completion ?? .finished,
            ),
        )
    }

    private func parseProposals(
        _ parsing: any ScanSpeechStateProtocol,
        parsedText: String,
    ) {
        guard let originalTranscript else {
            return
        }
        let factory = container.examinationNeuralModelFactory
        let request = DNeuralUltrasoundDictationParseRequest(
            selectedNeuralModelId: settingsAI.selectedNeuralModelId,
            text: parsedText,
            examinationTypeId: arguments.examinationType.id,
            examinationTypeTitle: arguments.examinationType.title,
            locale: container.language.currentLocale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: l10n.voice.dictation,
        )
        let started = Date()
        handle {
            let model = try factory.model(
                isFoundationModels: self.isFoundationModels,
            )
            return try await model.parseProposals(
                request: request,
            )
        } onMainSuccess: { proposal in
            guard self.isPresentationActive, self.state === parsing else {
                return
            }
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: originalTranscript,
                parsedText: parsedText,
                noComplaintsPattern: self.l10n.voice.dictation.pattern(
                    .noComplaintsValue,
                ),
            )
            if !plan.automatic.isEmpty {
                guard self.arguments.onConfirm?(
                    plan.automatic,
                ) == true else {
                    self.showTranscriptReview()
                    self.messager.showUnknownError(
                        l10n: self.l10n,
                    )
                    return
                }
                self.automaticFieldIds.formUnion(
                    plan.automatic.map(
                        \.id,
                    ),
                )
                self.analytics.actionCompleted(
                    .voiceProposalApplied,
                    parameters: .voiceProposalApplied(
                        proposals: plan.automatic,
                        source: .automatic,
                    ),
                )
            }
            self.analytics.actionCompleted(
                .voiceProposalsGenerated,
                parameters: .voiceProposalsGenerated(
                    proposal: proposal,
                    startedAt: started,
                ),
            )
            switch plan.decision {
            case .complete:
                self.isPresentationActive = false
                self.coordinator.dismissSheet()
            case .reviewTranscript:
                self.showTranscriptReview()
            case .reviewProposals:
                self.emit(
                    ScanSpeechReviewProposalState(
                        proposal: plan.proposal,
                        reviewProposals: plan.uncertain,
                    ),
                )
            }
        } onMainApiError: { error in
            self.onParsingFailed(
                error,
                parsing: parsing,
            )
        }
        onMainConnectionError: { error in
            self.onParsingFailed(
                error,
                parsing: parsing,
            )
        }
        onMainUnknownError: { error in
            self.onParsingFailed(
                error,
                parsing: parsing,
            )
        }
    }

    private func onParsingFailed(
        _: Error,
        parsing: any ScanSpeechStateProtocol,
    ) {
        guard isPresentationActive, state === parsing else {
            return
        }
        showTranscriptReview()
        messager.showUnknownError(
            l10n: l10n,
        )
    }
}
