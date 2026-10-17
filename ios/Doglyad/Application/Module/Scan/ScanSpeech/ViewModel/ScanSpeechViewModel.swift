import Combine
import DoglyadNeuralModel
import DoglyadSpeech
import DoglyadUI
import NestedObservableObject
import SwiftUI

@MainActor
final class ScanSpeechViewModel: DModuleViewModel<any ScanSpeechStateProtocol> {
    @NestedObservableObject var transcriptController = DTextFieldController()
    private(set) var originalTranscript: DSpeechTranscript?

    var textForParsing: String? {
        guard let originalTranscript else { return nil }
        return ScanSpeechReviewPolicy.textForParsing(
            transcript: originalTranscript,
            visibleText: transcriptController.text,
        )
    }

    var transcriptStatusDescription: LocalizedStringResource {
        guard let originalTranscript else { return l10n[
            .scanSpeechReviewFinishedDescription,
        ] }
        switch originalTranscript.completion {
        case .finished: return l10n[
                .scanSpeechReviewFinishedDescription,
            ]
        case .timedOut: return l10n[
                .scanSpeechReviewTimedOutDescription,
            ]
        case .interrupted: return l10n[
                .scanSpeechReviewInterruptedDescription,
            ]
        case .failed: return l10n[
                .scanSpeechReviewFailedDescription,
            ]
        case .cancelled: return l10n[
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

    let controller: any DSpeechControllerProtocol

    @Published var automaticFieldIds = Set<DNeuralUltrasoundVoiceFieldId>()
    // The speech factory exposes a protocol existential unsupported by the wrapper.

    private let messager: DMessager
    private let arguments: ScanSpeechArguments
    private var speechCancellable: AnyCancellable?
    private var presentationID: UUID? = UUID()

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: ScanSpeechArguments,
    ) {
        self.messager = messager
        self.arguments = arguments
        let contextualStrings = arguments.examinationType.contextualStrings
        let speechController = DSpeechFactory.make(
            locale: container.language.currentLocale,
            contextualStrings: contextualStrings,
            lexiconLocalization: container.l10n.voice.speech,
        )
        controller = speechController

        super.init(
            state: ScanSpeechPreparingModelState(
                preparation: .checking,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .scanSpeech,
            ),
        )
        observeSpeechController()
    }

    override func onInit() {
        controller.prepareModel()
        refreshSpeechState()
    }

    func onDisappear() {
        presentationID = nil
        cancelLastTask()
        controller.cancel()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .speechBack,
        )
        if automaticFieldIds.isEmpty { analytics.actionCompleted(
            .voiceFlowCancelled,
        ) }
        onDisappear()
        coordinator.dismissSheet()
    }

    func onTapRetryModelPreparation() {
        guard presentationID != nil else { return }
        controller.prepareModel()
        refreshSpeechState()
    }

    func onTapSpeech() {
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanSpeechReadyState:
            analytics.buttonTapped(
                .speechToggle,
                parameters: .speechToggle(
                    status: controller.status,
                ),
            )
            controller.start()
            container.examinationNeuralModelFactory.prewarm()
            refreshSpeechState()
        case _ as ScanSpeechRecordingState:
            analytics.buttonTapped(
                .speechToggle,
                parameters: .speechToggle(
                    status: controller.status,
                ),
            )
            stopSpeech()
        default: break
        }
    }

    func onTapRecordAgain() {
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanSpeechTranscriptReviewState: break
        default: return
        }

        controller.start()
        switch controller.status {
        case .preparing, .recording, .transcribing:
            emit(
                ScanSpeechReadyState(),
            )
            container.examinationNeuralModelFactory.prewarm()
            refreshSpeechState()
        case .stopped: break
        }
    }

    func onTapContinue() {
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanSpeechTranscriptReviewState:
            guard let speech = textForParsing, let originalTranscript else { return }
            if speech != originalTranscript.correctedText { analytics.actionCompleted(
                .voiceTranscriptEdited,
            ) }
            let parsing = ScanSpeechReviewParsingState(
                parsedText: speech,
            )
            emit(
                parsing,
            )
            parseProposals(
                parsing,
            )
        default: break
        }
    }

    func onTapProposal(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) {
        guard presentationID != nil else { return }
        switch state {
        case let state as ScanSpeechProposalReviewState:
            emit(
                ScanSpeechProposalReviewState(
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
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanSpeechProposalReviewState:
            showReview()
        default: break
        }
    }

    func onTapApplySelected() {
        guard presentationID != nil else { return }
        switch state {
        case let state as ScanSpeechProposalReviewState:
            guard !state.selectedFieldIds.isEmpty else { return }
            let selected = state.reviewProposals.filter { state.selectedFieldIds.contains(
                $0.id,
            ) }
            guard arguments.onConfirm?(
                selected,
            ) == true else { messager.showUnknownError(
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
            onDisappear()
            coordinator.dismissSheet()
        default: break
        }
    }

    func fieldTitle(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) -> LocalizedStringResource {
        switch id {
        case .examinationNumber: container.l10n[
                .scanExaminationNumberLabel,
            ]
        case .patientName: container.l10n[
                .scanPatientNameLabel,
            ]
        case .patientGender: container.l10n[
                .scanPatientGenderLabel,
            ]
        case .patientDateOfBirth: container.l10n[
                .scanPatientDateOfBirthLabel,
            ]
        case .patientHeightCM: container.l10n[
                .scanPatientHeightCMLabel,
            ]
        case .patientWeightKG: container.l10n[
                .scanPatientWeightKGLabel,
            ]
        case .patientComplaints: container.l10n[
                .scanPatientComplaintsLabel,
            ]
        case .examinationDescription: container.l10n[
                .scanExaminationDescriptionLabel,
            ]
        }
    }

    func warningText(
        _ warning: DNeuralVoiceProposalWarning,
    ) -> LocalizedStringResource {
        switch warning {
        case .ambiguousDictation: container.l10n[
                .scanSpeechProposalWarningAmbiguousDescription,
            ]
        case .sideMismatch: container.l10n[
                .scanSpeechProposalWarningSideDescription,
            ]
        case .negationMismatch: container.l10n[
                .scanSpeechProposalWarningNegationDescription,
            ]
        case .numberMismatch: container.l10n[
                .scanSpeechProposalWarningNumberDescription,
            ]
        case .unitMismatch: container.l10n[
                .scanSpeechProposalWarningUnitDescription,
            ]
        case .dateUnverified: container.l10n[
                .scanSpeechProposalWarningDateDescription,
            ]
        case .genderUnverified: container.l10n[
                .scanSpeechProposalWarningGenderDescription,
            ]
        case .identifierMismatch: container.l10n[
                .scanSpeechProposalWarningIdentifierDescription,
            ]
        case .textChanged: container.l10n[
                .scanSpeechProposalWarningTextChangedDescription,
            ]
        }
    }

    func proposedValue(
        _ value: DNeuralVoiceFieldValue,
    ) -> String {
        switch value {
        case let .text(
            text,
        ): text
        case let .gender(
            gender,
        ):
            switch gender {
            case .male: String(
                    localized: container.l10n[
                        .scanGenderMaleLabel,
                    ],
                )
            case .female: String(
                    localized: container.l10n[
                        .scanGenderFemaleLabel,
                    ],
                )
            }
        case let .date(
            date,
        ): date.formatted(
                Date.FormatStyle(
                    date: .abbreviated,
                    time: .omitted,
                ).locale(
                    l10n.locale,
                ),
            )
        case let .number(
            number,
        ): String(
                number,
            )
        }
    }

    func currentValue(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) -> String {
        arguments.getCurrentValue(
            id,
        )
    }

    private func observeSpeechController() {
        speechCancellable = controller.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshSpeechState() }
        }
    }

    private func refreshSpeechState() {
        guard presentationID != nil else { return }
        switch state {
        case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechAutomaticParsingState, _ as ScanSpeechProposalReviewState: return
        default: break
        }

        let next: any ScanSpeechStateProtocol
        switch controller.modelPreparation {
        case .checking, .downloading, .loading:
            next = ScanSpeechPreparingModelState(
                preparation: controller.modelPreparation,
            )
        case .failed:
            next = ScanSpeechModelPreparationFailedState()
        case .ready:
            switch controller.status {
            case .preparing: next = ScanSpeechPreparingRecordingState()
            case .recording: next = ScanSpeechRecordingState()
            case .transcribing: next = ScanSpeechTranscribingState()
            case .stopped:
                if let transcript = controller.lastTranscript { processTranscript(
                    transcript,
                )
                return
                }
                next = ScanSpeechReadyState()
            }
        }
        // Audio meter and interim text changes already flow through the self.
        switch (state, next) {
        case (_ as ScanSpeechReadyState, _ as ScanSpeechReadyState),
             (_ as ScanSpeechRecordingState, _ as ScanSpeechRecordingState),
             (_ as ScanSpeechPreparingRecordingState, _ as ScanSpeechPreparingRecordingState),
             (_ as ScanSpeechTranscribingState, _ as ScanSpeechTranscribingState),
             (_ as ScanSpeechModelPreparationFailedState, _ as ScanSpeechModelPreparationFailedState): return
        default: emit(
                next,
            )
        }
    }

    private func stopSpeech() {
        let controller = controller
        let id = presentationID
        emit(
            ScanSpeechTranscribingState(),
        )
        Task { [weak self] in
            let transcript = await controller.stop()
            guard let self, let id, presentationID == id else { return }
            switch state {
            case _ as ScanSpeechTranscriptReviewState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechAutomaticParsingState, _ as ScanSpeechProposalReviewState: return
            default: break
            }
            guard let transcript else { emit(
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
        originalTranscript = original
        transcriptController.setText(
            original.correctedText,
        )
        guard original.isReadyForParsing else { showReview()
            return
        }
        let parsing = ScanSpeechAutomaticParsingState(
            parsedText: original.correctedText,
        )
        emit(
            parsing,
        )
        parseProposals(
            parsing,
        )
    }

    private func showReview() {
        emit(
            ScanSpeechTranscriptReviewState(),
        )
        analytics.actionCompleted(
            .voiceDictationReviewed,
            parameters: .dictationReviewed(
                completion: originalTranscript?.completion ?? .finished,
            ),
        )
    }

    private func parseProposals(
        _ parsing: any ScanSpeechParsingStateProtocol,
    ) {
        guard let originalTranscript else { return }
        let factory = container.examinationNeuralModelFactory
        let request = DNeuralUltrasoundDictationParseRequest(
            text: parsing.parsedText,
            examinationTypeId: arguments.examinationType.id,
            examinationTypeTitle: arguments.examinationType.title,
            locale: container.language.currentLocale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: l10n.voice.dictation,
        )
        let started = Date()
        let id = presentationID
        handle {
            let model = try factory.model()
            return try await model.parseProposals(
                request: request,
            )
        } onMainSuccess: { proposal in
            guard let id, self.presentationID == id, ObjectIdentifier(
                self.state,
            ) == ObjectIdentifier(
                parsing,
            ) else { return }
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: originalTranscript,
                parsedText: parsing.parsedText,
                noComplaintsPattern: self.l10n.voice.dictation.pattern(
                    .noComplaintsValue,
                ),
            )
            if !plan.automatic.isEmpty {
                guard self.arguments.onConfirm?(
                    plan.automatic,
                ) == true else {
                    self.showReview()
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
            if plan.uncertain.isEmpty, proposal.rejectedFieldIds.isEmpty, proposal.unmappedFindings.isEmpty, !plan.automatic.isEmpty {
                self.onDisappear()
                self.coordinator.dismissSheet()
            } else if proposal.proposals.isEmpty, proposal.rejectedFieldIds.isEmpty, proposal.unmappedFindings.isEmpty {
                self.showReview()
            } else {
                self.emit(
                    ScanSpeechProposalReviewState(
                        proposal: proposal,
                        reviewProposals: plan.uncertain,
                    ),
                )
            }
        } onMainApiError: { error in self.onParsingFailed(
            error,
            parsing: parsing,
            presentationID: id,
        ) }
        onMainConnectionError: { error in self.onParsingFailed(
            error,
            parsing: parsing,
            presentationID: id,
        ) }
        onMainUnknownError: { error in self.onParsingFailed(
            error,
            parsing: parsing,
            presentationID: id,
        ) }
    }

    private func onParsingFailed(
        _: Error,
        parsing: any ScanSpeechParsingStateProtocol,
        presentationID id: UUID?,
    ) {
        guard let id, presentationID == id, ObjectIdentifier(
            state,
        ) == ObjectIdentifier(
            parsing,
        ) else { return }
        showReview()
        messager.showUnknownError(
            l10n: l10n,
        )
    }
}
