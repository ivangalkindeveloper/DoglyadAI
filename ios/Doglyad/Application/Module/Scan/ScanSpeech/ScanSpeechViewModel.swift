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
    private var isActive = true
    let transcriptController = DTextFieldController()
    @Published private(set) var reviewTranscript: DictationTranscript?
    @Published private(set) var dictationProposal: DictationProposal?
    @Published private(set) var selectedFieldIds = Set<VoiceFieldId>()
    @Published private(set) var reviewProposals: [VoiceFieldProposal] = []
    @Published private(set) var automaticFieldIds = Set<VoiceFieldId>()
    @Published private(set) var isParsingAutomatically = false

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: ScanSpeechBottomSheetArguments
    ) {
        self.messager = messager
        self.arguments = arguments
        let contextualStrings = arguments.examinationType.contextualStrings
        speechController = DSpeechFactory.makeDefault(
            locale: container.language.currentLocale,
            contextualStrings: contextualStrings
        )
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.scanSpeech)
        )
        observeSpeechController()
        transcriptCancellable = transcriptController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    override func onInit() {
        let locale = container.language.currentLocale
        let contextualStrings = arguments.examinationType.contextualStrings
        Task { [weak self] in
            let controller = await DSpeechFactory.make(
                locale: locale,
                contextualStrings: contextualStrings
            )
            guard let self else { return }
            guard self.isActive, !self.isLoading else { return }
            switch self.speechController.status {
            case .stopped:
                break
            case .preparing, .recording:
                return
            @unknown default:
                fatalError()
            }
            guard type(of: controller) != type(of: self.speechController) else { return }

            self.objectWillChange.send()
            self.speechController = controller
            self.observeSpeechController()
        }
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
        guard isActive, !isLoading, reviewTranscript == nil,
              let transcript = speechController.lastTranscript else { return }
        switch speechController.status {
        case .stopped:
            processTranscript(transcript)
        case .preparing, .recording:
            break
        @unknown default:
            fatalError()
        }
    }

    private func showReview(_ transcript: DictationTranscript) {
        transcriptController.setText(transcript.correctedText)
        reviewTranscript = transcript
        isParsingAutomatically = false
        isLoading = false
        analytics.actionCompleted(.voiceDictationReviewed, parameters: AnalyticsParameters([
            .result: .string(transcript.completion.rawValue),
        ]))
    }

    @Published var isLoading = false
    var isReviewVisible: Bool { reviewTranscript != nil && !isParsingAutomatically }
    var isProposalVisible: Bool { dictationProposal != nil }
    var isApplyDisabled: Bool { isLoading || selectedFieldIds.isEmpty }
    var proposalInstructions: LocalizedStringResource {
        automaticFieldIds.isEmpty ? .speechProposalInstructions : .speechProposalInstructionsWithAutomatic
    }

    var reviewStatusDescription: LocalizedStringResource? {
        guard let reviewTranscript else { return nil }
        switch reviewTranscript.completion {
        case .finished:
            return .speechReviewFinishedDescription
        case .timedOut:
            return .speechReviewTimedOutDescription
        case .interrupted:
            return .speechReviewInterruptedDescription
        case .failed:
            return .speechReviewFailedDescription
        case .cancelled:
            return .speechReviewCancelledDescription
        }
    }

    var isReviewContinueDisabled: Bool {
        guard let reviewTranscript else { return true }
        return isLoading || ScanSpeechReviewPolicy.textForParsing(
            transcript: reviewTranscript,
            visibleText: transcriptController.text
        ) == nil
    }

    func onTapBack() {
        analytics.buttonTapped(.speechBack)
        if automaticFieldIds.isEmpty {
            analytics.actionCompleted(.voiceFlowCancelled)
        }
        coordinator.dismissSheet()
    }

    func onDisappear() {
        isActive = false
        speechController.cancel()
    }

    var speechIcon: ImageResource {
        switch speechController.status {
        case .preparing,
             .recording:
            return .check
        case .stopped:
            return .play
        @unknown default:
            fatalError()
        }
    }

    var isSpeechButtonLoading: Bool {
        guard !isLoading else { return true }

        switch speechController.status {
        case .preparing:
            return true
        case .recording,
             .stopped:
            return false
        @unknown default:
            fatalError()
        }
    }

    var isAudioMeterVisible: Bool {
        switch speechController.status {
        case .recording:
            return true
        case .preparing,
             .stopped:
            return false
        @unknown default:
            fatalError()
        }
    }

    var isPreparingDescriptionVisible: Bool {
        switch speechController.status {
        case .preparing:
            return true
        case .recording,
             .stopped:
            return false
        @unknown default:
            fatalError()
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
        guard isActive, !isLoading, reviewTranscript == nil else { return }

        analytics.buttonTapped(
            .speechToggle,
            parameters: AnalyticsParameters([
                .source: .string(speechStatusAnalyticsValue),
            ])
        )

        switch speechController.status {
        case .preparing:
            return
        case .recording:
            onStopSpeech()
        case .stopped:
            speechController.start()
            container.examinationNeuralModelFactory?.prewarm()
        @unknown default:
            fatalError()
        }
    }

    private var speechStatusAnalyticsValue: String {
        switch speechController.status {
        case .preparing:
            "preparing"
        case .recording:
            "recording"
        case .stopped:
            "stopped"
        @unknown default:
            "unknown"
        }
    }

    private func onStopSpeech() {
        isLoading = true
        let controller = speechController

        Task { [weak self] in
            guard let self else { return }

            let transcript = await controller.stop()
            guard self.isActive else { return }
            guard let transcript else {
                self.isLoading = false
                return
            }
            self.processTranscript(transcript)
        }
    }

    private func processTranscript(_ transcript: DictationTranscript) {
        guard transcript.isReadyForParsing,
              container.examinationNeuralModelFactory != nil
        else {
            showReview(transcript)
            return
        }
        reviewTranscript = transcript
        transcriptController.setText(transcript.correctedText)
        isParsingAutomatically = true
        isLoading = true
        onParseProposals(speech: transcript.correctedText)
    }

    func onTapRecordAgain() {
        guard isActive, !isLoading, reviewTranscript != nil, dictationProposal == nil else { return }
        speechController.start()
        switch speechController.status {
        case .preparing, .recording:
            reviewTranscript = nil
            transcriptController.clear()
            container.examinationNeuralModelFactory?.prewarm()
        case .stopped:
            break
        @unknown default:
            fatalError()
        }
    }

    func onTapContinue() {
        guard isActive, !isLoading, dictationProposal == nil, let reviewTranscript,
              let speech = ScanSpeechReviewPolicy.textForParsing(
                  transcript: reviewTranscript,
                  visibleText: transcriptController.text
              ) else { return }
        guard container.examinationNeuralModelFactory != nil else {
            messager.showUnknownError()
            return
        }

        if speech != reviewTranscript.correctedText {
            analytics.actionCompleted(.voiceTranscriptEdited)
        }

        isLoading = true
        onParseProposals(speech: speech)
    }

    private func onParseProposals(
        speech: String
    ) {
        guard let factory = container.examinationNeuralModelFactory else { return }
        let request = DictationParseRequest(
            text: speech,
            examinationTypeId: arguments.examinationType.id,
            locale: container.language.currentLocale,
            allowedFields: VoiceFieldId.allCases
        )
        let started = Date()

        handle {
            try await factory.parseProposals(request: request)
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { proposal in
            guard self.isActive else { return }
            guard let transcript = self.reviewTranscript else { return }
            let plan = ScanSpeechConfidencePolicy.plan(
                proposal: proposal,
                transcript: transcript,
                parsedText: speech
            )
            if !plan.automatic.isEmpty {
                guard self.arguments.onConfirm?(plan.automatic) == true else {
                    self.showReview(transcript)
                    self.messager.showUnknownError()
                    return
                }
                self.automaticFieldIds.formUnion(plan.automatic.map(\.id))
                self.analytics.actionCompleted(.voiceProposalApplied, parameters: AnalyticsParameters([
                    .source: .string("automatic"),
                    .itemCount: .int(plan.automatic.count),
                    .warningCount: .int(0),
                ]))
            }
            self.isParsingAutomatically = false
            self.reviewProposals = plan.uncertain
            self.selectedFieldIds = []
            self.analytics.actionCompleted(.voiceProposalsGenerated, parameters: AnalyticsParameters([
                .itemCount: .int(proposal.proposals.count),
                .warningCount: .int(proposal.proposals.reduce(0) { $0 + $1.warnings.count }),
                .rejectedCount: .int(proposal.rejectedFieldIds.count),
                .durationMs: .int(Int(Date().timeIntervalSince(started) * 1000)),
            ]))
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
                self.showReview(transcript)
            } else {
                self.dictationProposal = proposal
            }
        } onUnknownError: { _ in
            guard self.isActive else { return }
            if let transcript = self.reviewTranscript {
                self.showReview(transcript)
            }
            self.messager.showUnknownError()
        }
    }

    func isSelected(_ id: VoiceFieldId) -> Bool {
        selectedFieldIds.contains(id)
    }

    func onTapProposal(_ id: VoiceFieldId) {
        guard !isLoading else { return }
        if selectedFieldIds.contains(id) {
            selectedFieldIds.remove(id)
        } else {
            selectedFieldIds.insert(id)
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
        let selected = reviewProposals.filter { selectedFieldIds.contains($0.id) }
        guard arguments.onConfirm?(selected) == true else {
            messager.showUnknownError()
            return
        }
        analytics.actionCompleted(.voiceProposalApplied, parameters: AnalyticsParameters([
            .source: .string("reviewed"),
            .itemCount: .int(selected.count),
            .warningCount: .int(selected.reduce(0) { $0 + $1.warnings.count }),
        ]))
        coordinator.dismissSheet()
    }

    func fieldTitle(_ id: VoiceFieldId) -> LocalizedStringResource {
        switch id {
        case .examinationNumber: .scanExaminationNumberLabel
        case .patientName: .scanPatientNameLabel
        case .patientGender: .scanPatientGenderLabel
        case .patientDateOfBirth: .scanPatientDateOfBirthLabel
        case .patientHeightCM: .scanPatientHeightCMLabel
        case .patientWeightKG: .scanPatientWeightKGLabel
        case .patientComplaints: .scanPatientComplaintsLabel
        case .examinationDescription: .scanExaminationDescriptionLabel
        }
    }

    func warningText(_ warning: VoiceProposalWarning) -> LocalizedStringResource {
        switch warning {
        case .ambiguousDictation: .speechProposalWarningAmbiguous
        case .sideMismatch: .speechProposalWarningSide
        case .negationMismatch: .speechProposalWarningNegation
        case .numberMismatch: .speechProposalWarningNumber
        case .unitMismatch: .speechProposalWarningUnit
        case .dateUnverified: .speechProposalWarningDate
        case .genderUnverified: .speechProposalWarningGender
        case .identifierMismatch: .speechProposalWarningIdentifier
        case .textChanged: .speechProposalWarningTextChanged
        }
    }

    func proposedValue(_ value: VoiceFieldValue) -> String {
        switch value {
        case let .text(text): text
        case let .gender(gender):
            switch gender {
            case .male: String(localized: .scanGenderMaleLabel)
            case .female: String(localized: .scanGenderFemaleLabel)
            }
        case let .date(date): date.formatted(date: .abbreviated, time: .omitted)
        case let .number(number): String(number)
        }
    }

    func currentValue(_ id: VoiceFieldId) -> String {
        arguments.getCurrentValue(id)
    }
}
