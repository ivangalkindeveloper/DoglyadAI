import Combine
@testable import Doglyad
import DoglyadNeuralModel
import DoglyadSpeech
import Foundation
import Testing

@MainActor
struct StatePublicationTests {
    @Test
    func synchronousRenderingDoesNotRetainThePreviousPhase() {
        let model = DStateViewModel<any ScanStateProtocol>(
            state: ScanInitializationLoadingState(),
        )
        var rendered: (any ScanStateProtocol)?
        var publications = 0
        let viewObservation = model.objectWillChange.sink {
            // Model the synchronous redraw observed while SwiftUI flushes input updates.
            rendered = model.state
        }
        let stateObservation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            viewObservation.cancel()
            stateObservation.cancel()
        }

        let ready = ScanInitialState()
        model.emit(
            ready,
        )
        #expect(
            rendered === ready,
        )
        #expect(
            publications == 1,
        )
    }

    @Test
    func equalStatelessStatesDoNotPublishOrReplaceTheCurrentInstance() {
        let initial = ScanSpeechReadyState()
        let model = DStateViewModel<any ScanSpeechStateProtocol>(
            state: initial,
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            ScanSpeechReadyState(),
        )
        #expect(
            publications == 0,
        )
        #expect(
            model.state === initial,
        )

        let recording = ScanSpeechRecordingState()
        model.emit(
            recording,
        )
        model.emit(
            ScanSpeechRecordingState(),
        )
        #expect(
            publications == 1,
        )
        #expect(
            model.state === recording,
        )
    }

    @Test
    func differentPhasesPublishEvenWhenTheirPayloadMatches() {
        let model = DStateViewModel<any ScanSpeechStateProtocol>(
            state: ScanSpeechAutomaticParsingLoadingState(
                parsedText: "Weight 70 kg",
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        let next = ScanSpeechReviewParsingLoadingState(
            parsedText: "Weight 70 kg",
        )
        model.emit(
            next,
        )
        #expect(
            publications == 1,
        )
        #expect(
            model.state === next,
        )
    }

    @Test
    func progressChangesPublishWithinTheSamePhase() {
        let model = DStateViewModel<any ScanSpeechStateProtocol>(
            state: ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: nil,
                ),
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: nil,
                ),
            ),
        )
        model.emit(
            ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: 0.2,
                ),
            ),
        )
        model.emit(
            ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: 0.2,
                ),
            ),
        )
        model.emit(
            ScanSpeechModelLoadingState(
                preparation: .downloading(
                    progress: 0.3,
                ),
            ),
        )
        model.emit(
            ScanSpeechModelLoadingState(
                preparation: .loading,
            ),
        )
        #expect(
            publications == 3,
        )
    }

    @Test
    func legalAcceptanceChangesPublishWithinTheSamePhase() {
        let model = DStateViewModel<any OnBoardingStateProtocol>(
            state: OnBoardingLegalState(
                isLegalAccepted: false,
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            OnBoardingLegalState(
                isLegalAccepted: false,
            ),
        )
        model.emit(
            OnBoardingLegalState(
                isLegalAccepted: true,
            ),
        )
        model.emit(
            OnBoardingLegalState(
                isLegalAccepted: true,
            ),
        )
        #expect(
            publications == 1,
        )
    }

    @Test
    func proposalSelectionAndProposalContentsBothPublishChanges() {
        let field = DNeuralUltrasoundVoiceFieldProposal(
            id: .patientWeightKG,
            value: .number(
                70,
            ),
            sourceQuote: "Weight 70 kg",
        )
        let proposal = DNeuralUltrasoundDictationProposal(
            source: .serverModel,
            proposals: [field],
        )
        let model = DStateViewModel<any ScanSpeechStateProtocol>(
            state: ScanSpeechReviewProposalState(
                proposal: proposal,
                reviewProposals: [field],
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            ScanSpeechReviewProposalState(
                proposal: proposal,
                reviewProposals: [field],
            ),
        )
        model.emit(
            ScanSpeechReviewProposalState(
                proposal: proposal,
                reviewProposals: [field],
                selectedFieldIds: [.patientWeightKG],
            ),
        )
        let updated = DNeuralUltrasoundDictationProposal(
            source: proposal.source,
            proposals: proposal.proposals,
            fieldSources: [.patientWeightKG: .explicitFacts],
        )
        model.emit(
            ScanSpeechReviewProposalState(
                proposal: updated,
                reviewProposals: [field],
                selectedFieldIds: [.patientWeightKG],
            ),
        )
        #expect(
            publications == 2,
        )
    }

    @Test
    func preservedStatesCompareTheirContentsThroughTheFeatureProtocol() {
        let model = DStateViewModel<any PaywallStateProtocol>(
            state: PaywallRestoreLoadingState(
                previousState: PaywallLoadingFailedState(
                    errorDescription: "First failure",
                ),
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            PaywallRestoreLoadingState(
                previousState: PaywallLoadingFailedState(
                    errorDescription: "First failure",
                ),
            ),
        )
        model.emit(
            PaywallRestoreLoadingState(
                previousState: PaywallLoadingFailedState(
                    errorDescription: "Second failure",
                ),
            ),
        )
        #expect(
            publications == 1,
        )
    }

    @Test
    func paywallPublishesSelectionPhaseAndFailureDataThroughItsBaseState() {
        let tier = SubscriptionTier(
            id: .pro,
            title: "Server title",
            features: ["Server benefit"],
        )
        let first = SubscriptionPlan(
            id: "monthly",
            source: .apple,
            type: .pro,
            period: .monthly,
            title: "Month",
            price: "$9",
        )
        let second = SubscriptionPlan(
            id: "annual",
            source: .apple,
            type: .pro,
            period: .annual,
            title: "Year",
            price: "$99",
        )
        let content = PaywallSuccessState(
            tiers: [tier],
            plans: [first, second],
            selectedType: .pro,
            selectedPlanID: first.id,
        )
        let model = DStateViewModel<any PaywallStateProtocol>(
            state: content,
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }
        model.emit(
            PaywallSuccessState(
                copying: content,
            ),
        )
        #expect(
            publications == 0,
        )
        let selected = PaywallSuccessState(
            tiers: [tier],
            plans: [first, second],
            selectedType: .pro,
            selectedPlanID: second.id,
        )
        model.emit(
            selected,
        )
        model.emit(
            PaywallPurchaseLoadingState(
                content: selected,
                plan: second,
            ),
        )
        model.emit(
            PaywallPurchaseLoadingState(
                content: selected,
                plan: second,
            ),
        )
        model.emit(
            PaywallPendingState(
                content: selected,
                plan: second,
            ),
        )
        model.emit(
            PaywallPendingState(
                content: selected,
                plan: first,
            ),
        )
        model.emit(
            PaywallOperationFailedState(
                previousState: selected,
                errorDescription: "First",
            ),
        )
        model.emit(
            PaywallOperationFailedState(
                previousState: selected,
                errorDescription: "First",
            ),
        )
        model.emit(
            PaywallOperationFailedState(
                previousState: selected,
                errorDescription: "Second",
            ),
        )
        #expect(
            publications == 6,
        )
        #expect(
            content.selectedPlan == first && selected.selectedPlan == second,
        )
    }

    @Test
    func errorsWithDifferentAssociatedValuesPublishTheirChanges() {
        let model = DStateViewModel<any ErrorRootStateProtocol>(
            state: ErrorRootServiceUnavailableState(
                error: InitializationError.serviceUnavailable(
                    email: "first@example.com",
                ),
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            ErrorRootServiceUnavailableState(
                error: InitializationError.serviceUnavailable(
                    email: "first@example.com",
                ),
            ),
        )
        let next = ErrorRootServiceUnavailableState(
            error: InitializationError.serviceUnavailable(
                email: "second@example.com",
            ),
        )
        model.emit(
            next,
        )
        #expect(
            publications == 1,
        )
        #expect(
            model.state === next,
        )
    }

    @Test
    func opaqueSwiftErrorsDoNotCollapseToTheirBridgedErrorCode() {
        let initial = WebDocumentFailedState(
            error: DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "First failure",
                ),
            ),
        )
        let model = DStateViewModel<any WebDocumentStateProtocol>(
            state: initial,
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            initial,
        )
        #expect(
            publications == 0,
        )

        let next = WebDocumentFailedState(
            error: DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "Second failure",
                ),
            ),
        )
        model.emit(
            next,
        )
        #expect(
            publications == 1,
        )
        #expect(
            model.state === next,
        )
    }

    @Test
    func nativeErrorsCompareTheirDomainCodeAndUserInfo() {
        let model = DStateViewModel<any WebDocumentStateProtocol>(
            state: WebDocumentFailedState(
                error: NSError(
                    domain: "StatePublicationTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "First failure"],
                ),
            ),
        )
        var publications = 0
        let observation = model.$state.dropFirst().sink { _ in
            publications += 1
        }
        defer {
            observation.cancel()
        }

        model.emit(
            WebDocumentFailedState(
                error: NSError(
                    domain: "StatePublicationTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "First failure"],
                ),
            ),
        )
        model.emit(
            WebDocumentFailedState(
                error: NSError(
                    domain: "StatePublicationTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Second failure"],
                ),
            ),
        )
        #expect(
            publications == 1,
        )
    }
}
