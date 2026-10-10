import Combine
import DoglyadNeuralModel
import DoglyadSpeech
import DoglyadUI
import SwiftUI

@MainActor
final class ScanSpeechViewModel: DViewModel {
    private let messager: DMessager
    private let arguments: ScanSpeechBottomSheetArguments
    private(set) var speechController: any DSpeechControllerProtocol
    private var speechCancellable: AnyCancellable?
    private var transcriptCancellable: AnyCancellable?
    // Ignore UI actions and asynchronous results after the sheet disappears.
    private var isSheetPresented = true
    // Editable review text; the original ASR result stays in reviewTranscript.
    let transcriptController = DTextFieldController()
    @Published private(set) var reviewTranscript: DSpeechTranscript?
    @Published private(set) var dictationProposal: DNeuralUltrasoundDictationProposal?
    @Published private(set) var selectedFieldIds = Set<DNeuralUltrasoundVoiceFieldId>()
    @Published private(set) var reviewProposals: [DNeuralUltrasoundVoiceFieldProposal] = []
    @Published private(set) var automaticFieldIds = Set<DNeuralUltrasoundVoiceFieldId>()
    @Published private(set) var isParsingAutomatically = false

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: ScanSpeechBottomSheetArguments,
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
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(
                .scanSpeech,
            ),
        )
        observeSpeechController()
        transcriptCancellable = transcriptController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    override func onInit() {
        speechController.prepareModel()
    }

    private func observeSpeechController() {
        speechCancellable = speechController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            Task { @MainActor [weak self] in
                self?.showAutomaticStopIfNeeded()
            }
        }
    }

    private func showAutomaticStopIfNeeded() {
        guard isSheetPresented, !isLoading, reviewTranscript == nil,
              let transcript = speechController.lastTranscript else { return }
        switch speechController.status {
        case .stopped:
            processTranscript(
                transcript,
            )
        case .preparing, .recording, .transcribing:
            break
        }
    }

    private func showReview(
        _ transcript: DSpeechTranscript,
    ) {
        transcriptController.setText(
            transcript.correctedText,
        )
        reviewTranscript = transcript
        isParsingAutomatically = false
        isLoading = false
        analytics.actionCompleted(
            .voiceDictationReviewed,
            parameters: .dictationReviewed(
                completion: transcript.completion,
            ),
        )
    }

    @Published var isLoading = false
    var modelPreparation: DSpeechModelPreparation { speechController.modelPreparation }
    var isModelReady: Bool {
        switch modelPreparation {
        case .ready:
            true
        case .checking, .downloading, .loading, .failed:
            false
        }
    }

    func onTapRetryModelPreparation() {
        guard isSheetPresented else { return }
        speechController.prepareModel()
    }

    var isReviewVisible: Bool { reviewTranscript != nil && !isParsingAutomatically }
    var isProposalVisible: Bool { dictationProposal != nil }
    var isApplyDisabled: Bool { isLoading || selectedFieldIds.isEmpty }
    var proposalInstructions: LocalizedStringResource {
        automaticFieldIds.isEmpty ? container.l10n[
            .speechProposalInstructions,
        ] : container.l10n[
            .speechProposalInstructionsWithAutomatic,
        ]
    }

    var reviewStatusDescription: LocalizedStringResource? {
        guard let reviewTranscript else { return nil }
        switch reviewTranscript.completion {
        case .finished:
            return container.l10n[
                .speechReviewFinishedDescription,
            ]
        case .timedOut:
            return container.l10n[
                .speechReviewTimedOutDescription,
            ]
        case .interrupted:
            return container.l10n[
                .speechReviewInterruptedDescription,
            ]
        case .failed:
            return container.l10n[
                .speechReviewFailedDescription,
            ]
        case .cancelled:
            return container.l10n[
                .speechReviewCancelledDescription,
            ]
        }
    }

    var isReviewContinueDisabled: Bool {
        guard let reviewTranscript else { return true }
        return isLoading || ScanSpeechReviewPolicy.textForParsing(
            transcript: reviewTranscript,
            visibleText: transcriptController.text,
        ) == nil
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
        coordinator.dismissSheet()
    }

    func onDisappear() {
        isSheetPresented = false
        speechController.cancel()
    }

    var speechIcon: ImageResource {
        switch speechController.status {
        case .preparing,
             .recording,
             .transcribing:
            .check
        case .stopped:
            .play
        }
    }

    var isSpeechButtonLoading: Bool {
        guard !isLoading else { return true }

        switch speechController.status {
        case .preparing, .transcribing:
            return true
        case .recording,
             .stopped:
            return false
        }
    }

    var isAudioMeterVisible: Bool {
        switch speechController.status {
        case .recording:
            true
        case .preparing,
             .transcribing,
             .stopped:
            false
        }
    }

    var processingDescription: LocalizedStringResource? {
        switch speechController.status {
        case .preparing:
            container.l10n[
                .speechProcessPreparingDescription,
            ]
        case .transcribing:
            container.l10n[
                .speechProcessTranscribingDescription,
            ]
        case .recording, .stopped:
            nil
        }
    }

    var speechText: String? {
        isAudioMeterVisible ? speechController.text : nil
    }

    var isSpeechTextVisible: Bool {
        speechText != nil
    }

    var audioMeterLevel: Float {
        speechController.audioMeter
    }

    func onTapSpeech() {
        guard isSheetPresented, isModelReady, !isLoading, reviewTranscript == nil else { return }

        analytics.buttonTapped(
            .speechToggle,
            parameters: .speechToggle(
                status: speechController.status,
            ),
        )

        switch speechController.status {
        case .preparing, .transcribing:
            return
        case .recording:
            onStopSpeech()
        case .stopped:
            speechController.start()
            container.examinationNeuralModelFactory.prewarm()
        }
    }

    private func onStopSpeech() {
        isLoading = true
        let controller = speechController

        Task { [weak self] in
            guard let self else { return }

            let transcript = await controller.stop()
            guard isSheetPresented else { return }
            guard let transcript else {
                isLoading = false
                return
            }
            guard reviewTranscript == nil else { return }
            processTranscript(
                transcript,
            )
        }
    }

    /// A finished, nonempty result starts extraction automatically. Other results
    /// first go to text review; field confidence is checked after extraction.
    private func processTranscript(
        _ transcript: DSpeechTranscript,
    ) {
        guard transcript.isReadyForParsing else {
            showReview(
                transcript,
            )
            return
        }
        reviewTranscript = transcript
        transcriptController.setText(
            transcript.correctedText,
        )
        isParsingAutomatically = true
        isLoading = true
        onParseProposals(
            speech: transcript.correctedText,
        )
    }

    func onTapRecordAgain() {
        guard isSheetPresented, !isLoading, reviewTranscript != nil, dictationProposal == nil else { return }
        speechController.start()
        switch speechController.status {
        case .preparing, .recording, .transcribing:
            reviewTranscript = nil
            transcriptController.clear()
            container.examinationNeuralModelFactory.prewarm()
        case .stopped:
            break
        }
    }

    func onTapContinue() {
        guard isSheetPresented, !isLoading, dictationProposal == nil, let reviewTranscript,
              let speech = ScanSpeechReviewPolicy.textForParsing(
                  transcript: reviewTranscript,
                  visibleText: transcriptController.text,
              ) else { return }
        if speech != reviewTranscript.correctedText {
            analytics.actionCompleted(
                .voiceTranscriptEdited,
            )
        }

        isLoading = true
        onParseProposals(
            speech: speech,
        )
    }

    private func onParseProposals(
        speech: String,
    ) {
        let factory = container.examinationNeuralModelFactory
        let request = DNeuralUltrasoundDictationParseRequest(
            text: speech,
            examinationTypeId: arguments.examinationType.id,
            examinationTypeTitle: arguments.examinationType.title,
            locale: container.language.currentLocale,
            allowedFields: DNeuralUltrasoundVoiceFieldId.allCases,
            localization: container.l10n.voice.dictation,
        )
        let started = Date()

        handle {
            let model = try factory.model()
            return try await model.parseProposals(
                request: request,
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { proposal in
            guard self.isSheetPresented else { return }
            guard let transcript = self.reviewTranscript else { return }
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: transcript,
                parsedText: speech,
                noComplaintsPattern: self.container.l10n.voice.dictation.pattern(
                    .noComplaintsValue,
                ),
            )
            if !plan.automatic.isEmpty {
                guard self.arguments.onConfirm?(
                    plan.automatic,
                ) == true else {
                    self.showReview(
                        transcript,
                    )
                    self.messager.showUnknownError(
                        l10n: self.container.l10n,
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
            self.isParsingAutomatically = false
            self.reviewProposals = plan.uncertain
            self.selectedFieldIds = []
            self.analytics.actionCompleted(
                .voiceProposalsGenerated,
                parameters: .voiceProposalsGenerated(
                    proposal: proposal,
                    startedAt: started,
                ),
            )
            if plan.uncertain.isEmpty,
               proposal.rejectedFieldIds.isEmpty,
               proposal.unmappedFindings.isEmpty,
               !plan.automatic.isEmpty
            {
                self.coordinator.dismissSheet()
            } else if proposal.proposals.isEmpty,
                      proposal.rejectedFieldIds.isEmpty,
                      proposal.unmappedFindings.isEmpty
            {
                self.showReview(
                    transcript,
                )
            } else {
                self.dictationProposal = proposal
            }
        } onUnknownError: { _ in
            guard self.isSheetPresented else { return }
            if let transcript = self.reviewTranscript {
                self.showReview(
                    transcript,
                )
            }
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func isSelected(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) -> Bool {
        selectedFieldIds.contains(
            id,
        )
    }

    func onTapProposal(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) {
        guard !isLoading else { return }
        if selectedFieldIds.contains(
            id,
        ) {
            selectedFieldIds.remove(
                id,
            )
        } else {
            selectedFieldIds.insert(
                id,
            )
        }
    }

    func onTapBackToTranscript() {
        guard !isLoading else { return }
        dictationProposal = nil
        reviewProposals = []
        selectedFieldIds = []
    }

    func onTapApplySelected() {
        guard !isApplyDisabled, dictationProposal != nil else { return }
        let selected = reviewProposals.filter { selectedFieldIds.contains(
            $0.id,
        ) }
        guard arguments.onConfirm?(
            selected,
        ) == true else {
            messager.showUnknownError(
                l10n: container.l10n,
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
        coordinator.dismissSheet()
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
                .speechProposalWarningAmbiguous,
            ]
        case .sideMismatch: container.l10n[
                .speechProposalWarningSide,
            ]
        case .negationMismatch: container.l10n[
                .speechProposalWarningNegation,
            ]
        case .numberMismatch: container.l10n[
                .speechProposalWarningNumber,
            ]
        case .unitMismatch: container.l10n[
                .speechProposalWarningUnit,
            ]
        case .dateUnverified: container.l10n[
                .speechProposalWarningDate,
            ]
        case .genderUnverified: container.l10n[
                .speechProposalWarningGender,
            ]
        case .identifierMismatch: container.l10n[
                .speechProposalWarningIdentifier,
            ]
        case .textChanged: container.l10n[
                .speechProposalWarningTextChanged,
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
                date: .abbreviated,
                time: .omitted,
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
}
