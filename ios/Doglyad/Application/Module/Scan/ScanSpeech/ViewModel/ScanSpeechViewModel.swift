import Combine
import DoglyadNeuralModel
import DoglyadSpeech
import DoglyadUI
import Foundation
import NestedObservableObject
import SwiftUI

@MainActor
final class ScanSpeechViewModel: DModuleViewModel<any ScanSpeechStateProtocol> {
    @NestedObservableObject var transcriptTextController = DTextFieldController()
    private(set) var originalTranscript: DSpeechTranscript?
    let speechController: any DSpeechControllerProtocol
    @Published var automaticFieldIds = Set<DNeuralUltrasoundVoiceFieldId>()
    private let messager: DMessager
    private let arguments: ScanSpeechArguments
    private var speechCancellable: AnyCancellable?
    private var isPresentationActive = true

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
        speechController = DSpeechFactory.make(
            locale: container.language.currentLocale,
            contextualStrings: contextualStrings,
            lexiconLocalization: container.l10n.voice.speech,
        )

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

    var textForParsing: String? {
        guard let originalTranscript else { return nil }
        let visibleText = transcriptTextController.text
        // Trimming only controls availability; preserve the editor text for parsing.
        let trimmed = visibleText.trimmingCharacters(
            in: .whitespacesAndNewlines,
        )
        guard !trimmed.isEmpty else { return nil }

        switch originalTranscript.completion {
        case .finished, .timedOut, .interrupted, .failed:
            return visibleText
        case .cancelled:
            return nil
        }
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

    override func onInit() {
        speechController.prepareModel()
        refreshSpeechState()
    }

    func onDisappear() {
        isPresentationActive = false
        cancelLastTask()
        speechController.cancel()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .speechBack,
        )
        if automaticFieldIds.isEmpty { analytics.actionCompleted(
            .voiceFlowCancelled,
        ) }
        isPresentationActive = false
        coordinator.dismissSheet()
    }

    func onTapRetryModelPreparation() {
        guard isPresentationActive else { return }
        speechController.prepareModel()
        refreshSpeechState()
    }

    func onTapSpeech() {
        guard isPresentationActive else { return }
        switch state {
        case _ as ScanSpeechReadyState:
            analytics.buttonTapped(
                .speechToggle,
                parameters: .speechToggle(
                    recordingStatus: speechController.recordingStatus,
                ),
            )
            speechController.start()
            container.examinationNeuralModelFactory.prewarm()
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
        guard isPresentationActive else { return }
        switch state {
        case _ as ScanSpeechReviewTranscriptState: break
        default: return
        }

        speechController.start()
        switch speechController.recordingStatus {
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
        guard isPresentationActive else { return }
        switch state {
        case _ as ScanSpeechReviewTranscriptState:
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
        guard isPresentationActive else { return }
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
        guard isPresentationActive else { return }
        switch state {
        case _ as ScanSpeechReviewProposalState:
            showTranscriptReview()
        default: break
        }
    }

    func onTapApplySelected() {
        guard isPresentationActive else { return }
        switch state {
        case let state as ScanSpeechReviewProposalState:
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
            isPresentationActive = false
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
        speechCancellable = speechController.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshSpeechState() }
        }
    }

    private func refreshSpeechState() {
        guard isPresentationActive else { return }
        switch state {
        case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechAutomaticParsingState, _ as ScanSpeechReviewProposalState: return
        default: break
        }

        let next: any ScanSpeechStateProtocol
        switch speechController.modelPreparationStatus {
        case .checking, .downloading, .loading:
            next = ScanSpeechPreparingModelState(
                preparation: speechController.modelPreparationStatus,
            )
        case .failed:
            next = ScanSpeechModelPreparationFailedState()
        case .ready:
            switch speechController.recordingStatus {
            case .preparing: next = ScanSpeechPreparingRecordingState()
            case .recording: next = ScanSpeechRecordingState()
            case .transcribing: next = ScanSpeechTranscribingState()
            case .stopped:
                if let transcript = speechController.lastTranscript { processTranscript(
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
        let speechController = speechController
        emit(
            ScanSpeechTranscribingState(),
        )
        Task { [weak self] in
            let transcript = await speechController.stop()
            guard let self, isPresentationActive else { return }
            switch state {
            case _ as ScanSpeechReviewTranscriptState, _ as ScanSpeechReviewParsingState, _ as ScanSpeechAutomaticParsingState, _ as ScanSpeechReviewProposalState: return
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
        originalTranscript = original
        transcriptTextController.setText(
            original.correctedText,
        )
        guard original.isReadyForParsing else {
            showTranscriptReview()
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
        handle {
            let model = try factory.model()
            return try await model.parseProposals(
                request: request,
            )
        } onMainSuccess: { proposal in
            guard self.isPresentationActive, self.state === parsing else { return }
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
        } onMainApiError: { error in self.onParsingFailed(
            error,
            parsing: parsing,
        ) }
        onMainConnectionError: { error in self.onParsingFailed(
            error,
            parsing: parsing,
        ) }
        onMainUnknownError: { error in self.onParsingFailed(
            error,
            parsing: parsing,
        ) }
    }

    private func onParsingFailed(
        _: Error,
        parsing: any ScanSpeechParsingStateProtocol,
    ) {
        guard isPresentationActive, state === parsing else { return }
        showTranscriptReview()
        messager.showUnknownError(
            l10n: l10n,
        )
    }
}
