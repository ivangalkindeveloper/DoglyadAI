import Combine
@testable import Doglyad
import DoglyadNeuralModel
@testable import DoglyadUI
import Foundation
import Router
import Testing
import UIKit

@MainActor
struct ModuleStateTests {
    @Test
    func subscriptionChangesReachModulesAndObservationIsReleased() throws {
        let container = DependencyContainer.previewable
        let root = SubscriptionRootViewModel(
            container: container,
        )
        root.update(
            status: nil,
        )
        var observedRequestCounts: [Int?] = []
        let statusObservation = root.observeStatus { status in
            observedRequestCounts.append(
                status?.availableCountPerDay,
            )
        }
        var requestCountUpdates = 0
        var observationCancelled = false
        var model: SubscriptionCustomerCenterViewModel? = SubscriptionCustomerCenterViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { root.status },
            observeSubscriptionStatus: { observer in
                let observation = root.observeStatus(
                    observer,
                )
                return AnyCancellable {
                    observationCancelled = true
                    observation.cancel()
                }
            },
            onSubscriptionStatusUpdated: { root.update(
                status: $0,
            ) },
            getNeuralModelSettings: { root.resolveNeuralModelSettings() },
            onRequestCountIncremented: { requestCountUpdates += 1 },
            arguments: nil,
            onRefreshStatus: {},
        )
        weak let weakModel = model
        #expect(
            model?.subscriptionStatus == nil,
        )
        #expect(
            model?.subscriptionAvailability(
                of: .neuralModelSettings,
            ) == .unavailable,
        )

        let status = SubscriptionStatus(
            type: .pro,
            entitlement: SubscriptionEntitlement(
                requestCountPerDay: 20,
                formCompletionViaMicrophone: .available,
                sendingReportByEmail: .available,
                neuralModelSettings: .available,
            ),
            availableCountPerDay: 17,
        )
        root.update(
            status: status,
        )
        #expect(
            model?.subscriptionStatus != nil,
        )
        #expect(
            model?.availableRequestCount == 17,
        )
        #expect(
            model?.subscriptionAvailability(
                of: .neuralModelSettings,
            ) == .available,
        )
        #expect(
            model?.subscriptionAvailability(
                of: .sendingReportByEmail,
            ) == .available,
        )

        model?.incrementRequestCount()
        #expect(
            requestCountUpdates == 1,
        )
        model?.updateSubscriptionStatus(
            nil,
        )
        #expect(
            root.status == nil,
        )
        #expect(
            model?.subscriptionAvailability(
                of: .neuralModelSettings,
            ) == .unavailable,
        )
        model = nil
        #expect(
            weakModel == nil,
        )
        #expect(
            observationCancelled,
        )
        #expect(
            observedRequestCounts == [nil, 17, nil],
        )
        statusObservation.cancel()
    }

    @Test
    func examinationChangesReachScanAndObservationIsReleased() {
        let container = DependencyContainer.previewable
        let initialModel = container.usExaminationNeuralModelDefault
        var selectedModel = initialModel
        var selectedTemplate: USExaminationTemplate?
        let changes = PassthroughSubject<Void, Never>()
        var observationCancelled = false
        var model: ScanViewModel? = ScanViewModel(
            container: container,
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            observeExaminationChanges: { observer in
                let observation = changes.sink { _ in observer() }
                return AnyCancellable {
                    observationCancelled = true
                    observation.cancel()
                }
            },
            getSelectedTemplate: { selectedTemplate },
            onTemplateSelected: { _ in },
            onTemplateReset: {},
            getNeuralModel: { selectedModel },
            onNeuralModelSelected: { _ in },
        )
        weak let weakModel = model
        selectedModel = USExaminationNeuralModel(
            id: "updated-model",
            title: "Updated model",
            entitlement: initialModel.entitlement,
            accessibility: initialModel.accessibility,
            contextLength: initialModel.contextLength,
            description: initialModel.description,
        )
        selectedTemplate = USExaminationTemplate(
            usExaminationType: container.usExaminationTypeDefault,
            name: "Selected template",
            content: "Template content",
        )
        changes.send()
        #expect(
            model?.neuralModel == selectedModel,
        )
        #expect(
            model?.template == selectedTemplate,
        )
        model = nil
        #expect(
            weakModel == nil,
        )
        #expect(
            observationCancelled,
        )
    }

    @Test
    func photoViewerTracksSourceChangesAndDeletesThroughArguments() {
        let container = DependencyContainer.previewable
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let first = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let second = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let third = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let source = CurrentValueSubject<[USExaminationScanPhoto], Never>(
            [first, second],
        )
        let arguments = PhotoViewArguments(
            getPhotos: { source.value },
            observePhotos: { source.sink(
                receiveValue: $0,
            ) },
            initialPhotoID: first.id,
            onDelete: { photo in source.send(
                source.value.filter { $0.id != photo.id },
            ) },
        )
        let router = DRouter(
            initialRoute: RouteScreen(
                type: .scan,
            ),
        )
        router.push(
            route: RouteScreen(
                type: .photoView,
                arguments: arguments,
            ),
        )
        let model = PhotoViewViewModel(
            container: container,
            router: router,
            getSubscriptionStatus: { root.status },
            observeSubscriptionStatus: { root.observeStatus(
                $0,
            ) },
            onSubscriptionStatusUpdated: { root.update(
                status: $0,
            ) },
            getNeuralModelSettings: { root.resolveNeuralModelSettings() },
            onRequestCountIncremented: {},
            arguments: arguments,
        )
        model.onTapDelete()
        #expect(
            source.value.map(
                \.id,
            ) == [second.id],
        )
        #expect(
            model.photos.map(
                \.id,
            ) == [second.id],
        )
        #expect(
            model.selectedPhotoID == second.id,
        )
        source.send(
            [second, third],
        )
        #expect(
            model.photos.map(
                \.id,
            ) == [second.id, third.id],
        )
        #expect(
            model.currentPage == 1,
        )
        source.send(
            [],
        )
        switch model.state {
        case _ as PhotoViewEmptyState: break
        default: Issue.record(
                "Deleting the last photo must publish the empty state",
            )
        }
        #expect(
            router.path.isEmpty,
        )
    }

    @Test
    func dateSelectionPublishesChangesAndConfirmsLatestValue() {
        let container = DependencyContainer.previewable
        let initialDate = Date(
            timeIntervalSince1970: 631152000,
        )
        let updatedDate = Date(
            timeIntervalSince1970: 946684800,
        )
        var selectedDate: Date?
        let model = SelectDateOfBirthViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            arguments: SelectDateOfBirthArguments(
                currentValue: initialDate,
                onSelected: { selectedDate = $0 },
            ),
        )
        let fromDate = model.fromDate
        let toDate = model.toDate
        var publishedDates: [Date] = []
        let observation = model.$date.sink { publishedDates.append(
            $0,
        ) }

        model.onDateChanged(
            updatedDate,
        )
        model.onTapSelect()

        #expect(
            publishedDates == [initialDate, updatedDate],
        )
        #expect(
            selectedDate == updatedDate,
        )
        #expect(
            model.fromDate == fromDate && model.toDate == toDate,
        )
        observation.cancel()
    }

    @Test
    func legalAcceptanceEmitsImmutableSnapshotsAndKeepsConsentGate() {
        let container = DependencyContainer.previewable
        let model = OnBoardingViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .onBoarding,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
        )
        let initial = OnBoardingLegalState()
        model.emit(
            initial,
        )
        var snapshots: [OnBoardingLegalState] = []
        let observation = model.$state.dropFirst().sink { state in
            switch state {
            case let state as OnBoardingLegalState: snapshots.append(
                    state,
                )
            default: break
            }
        }
        model.onLegalAcceptedChanged(
            true,
        )
        model.onLegalAcceptedChanged(
            false,
        )
        #expect(
            snapshots.map(
                \.isLegalAccepted,
            ) == [true, false],
        )
        #expect(
            !initial.isLegalAccepted,
        )
        model.onPressedNext()
        #expect(
            snapshots.count == 2,
        )
        switch model.state {
        case _ as OnBoardingLegalState: break
        default: Issue.record(
                "Onboarding must require legal acceptance",
            )
        }
        model.onLegalAcceptedChanged(
            true,
        )
        model.onPressedNext()
        switch model.state {
        case _ as OnBoardingExaminationTypeState: break
        default: Issue.record(
                "Accepted terms must allow the next onboarding step",
            )
        }
        model.onLegalAcceptedChanged(
            false,
        )
        #expect(
            snapshots.map(
                \.isLegalAccepted,
            ) == [true, false, true],
        )
        observation.cancel()
    }

    @Test
    func proposalSelectionEmitsSnapshotsAndPreservesReviewData() {
        let container = DependencyContainer.previewable
        var appliedFieldIds: [DNeuralUltrasoundVoiceFieldId] = []
        let model = ScanSpeechViewModel(
            container: container,
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            arguments: ScanSpeechArguments(
                examinationType: container.usExaminationTypeDefault,
                getCurrentValue: { _ in "" },
                onConfirm: { proposals in
                    appliedFieldIds = proposals.map(
                        \.id,
                    )
                    return true
                },
            ),
        )
        let reviewProposals = [
            DNeuralUltrasoundVoiceFieldProposal(
                id: .patientName,
                value: .text(
                    "Patient",
                ),
                sourceQuote: "Patient",
            ),
            DNeuralUltrasoundVoiceFieldProposal(
                id: .patientWeightKG,
                value: .number(
                    70,
                ),
                sourceQuote: "70 kg",
            ),
        ]
        let proposal = DNeuralUltrasoundDictationProposal(
            source: .serverModel,
            proposals: reviewProposals,
            unmappedFindings: ["Unmapped finding"],
            rejectedFieldIds: [.patientHeightCM],
        )
        let initial = ScanSpeechReviewProposalState(
            proposal: proposal,
            reviewProposals: reviewProposals,
        )
        model.emit(
            initial,
        )
        var snapshots: [ScanSpeechReviewProposalState] = []
        let observation = model.$state.dropFirst().sink { state in
            switch state {
            case let state as ScanSpeechReviewProposalState: snapshots.append(
                    state,
                )
            default: break
            }
        }
        model.onTapProposal(
            .patientName,
        )
        model.onTapProposal(
            .patientWeightKG,
        )
        model.onTapProposal(
            .patientName,
        )
        #expect(
            initial.selectedFieldIds.isEmpty,
        )
        #expect(
            snapshots.map(
                \.selectedFieldIds,
            ) == [
                Set(
                    [DNeuralUltrasoundVoiceFieldId.patientName],
                ),
                Set(
                    [.patientName, .patientWeightKG],
                ),
                Set(
                    [.patientWeightKG],
                ),
            ],
        )
        #expect(
            snapshots.allSatisfy {
                $0.reviewProposals == reviewProposals
                    && $0.proposal.proposals == proposal.proposals
                    && $0.proposal.unmappedFindings == proposal.unmappedFindings
                    && $0.proposal.rejectedFieldIds == proposal.rejectedFieldIds
            },
        )
        model.onTapApplySelected()
        #expect(
            appliedFieldIds == [.patientWeightKG],
        )
        observation.cancel()
    }

    @Test
    func sharedControllersPublishWithoutReplacingStateAndSurvivePhaseTransition() {
        let container = DependencyContainer.previewable
        let model = TemplateAddViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            messager: DMessager(),
            onSaveTemplate: { _ in },
        )
        let controller = model.nameController
        var transitions = 0
        var changes = 0
        let stateObservation = model.$state.dropFirst().sink { _ in transitions += 1 }
        let changeObservation = model.objectWillChange.sink { changes += 1 }
        controller.setText(
            "Entered name",
        )
        #expect(
            changes > 0,
        )
        #expect(
            transitions == 0,
        )
        model.emit(
            TemplateAddDefaultState(),
        )
        #expect(
            transitions == 1,
        )
        changes = 0
        controller.setText(
            "Edited name",
        )
        #expect(
            changes > 0,
        )
        #expect(
            transitions == 1,
        )
        #expect(
            model.nameController === controller,
        )
        #expect(
            model.nameController.text == "Edited name",
        )
        stateObservation.cancel()
        changeObservation.cancel()
    }

    @Test
    func photoRemarksFollowTheNewReportWhenPhotosHaveNotChanged() {
        let container = DependencyContainer.previewable
        let photo = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let originalPoint = USExaminationPhotoRemarkPoint(
            x: 0.2,
            y: 0.3,
            title: "Original",
            description: "Original finding",
        )
        let updatedPoint = USExaminationPhotoRemarkPoint(
            x: 0.6,
            y: 0.7,
            title: "Updated",
            description: "Updated finding",
        )
        let examination = USExaminationData(
            usExaminationTypeId: "test",
            photos: [photo],
            examinationNumber: "1",
            patientName: "Patient",
            patientGender: .male,
            patientDateOfBirth: Date(),
            patientHeight: nil,
            patientWeight: nil,
            patientComplaints: nil,
            examinationDescription: "Examination",
        )
        let report = USExaminationReport(
            date: Date(),
            neuralModelSettings: container.initialNeuralModelSettings,
            examinationData: examination,
            actualModelReport: USExaminationModelReport(
                date: Date(),
                modelId: "test",
                description: "Description",
                conclusion: "Conclusion",
                recommendations: nil,
                photoRemarks: [USExaminationPhotoRemarks(
                    photoId: photo.id,
                    points: [originalPoint],
                )],
            ),
            previousModelReports: [],
        )
        let source = ReportDetailViewModel(
            container: container,
            messager: DMessager(),
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .scan,
                ),
            ),
            initialReport: report,
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            observeExaminationChanges: { _ in AnyCancellable {} },
            getSelectedTemplate: { nil },
            getNeuralModel: { container.usExaminationNeuralModelDefault },
            onNeuralModelSelected: { _ in },
        )
        let arguments = PhotoViewArguments(
            getPhotos: { source.report.examinationData.photos },
            getPhotoRemarks: { source.report.actualModelReport.photoRemarks },
            observePhotos: { observer in source.$report.map(
                \.examinationData.photos,
            ).sink(
                receiveValue: observer,
            ) },
            initialPhotoID: photo.id,
        )
        let model = PhotoViewViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .photoView,
                    arguments: arguments,
                ),
            ),
            getSubscriptionStatus: { nil },
            observeSubscriptionStatus: { _ in AnyCancellable {} },
            onSubscriptionStatusUpdated: { _ in },
            getNeuralModelSettings: { container.initialNeuralModelSettings },
            onRequestCountIncremented: {},
            arguments: arguments,
        )
        source.report = USExaminationReport(
            id: report.id,
            date: report.date,
            neuralModelSettings: report.neuralModelSettings,
            examinationData: examination,
            actualModelReport: USExaminationModelReport(
                date: Date(),
                modelId: "test",
                description: "Updated description",
                conclusion: "Updated conclusion",
                recommendations: nil,
                photoRemarks: [USExaminationPhotoRemarks(
                    photoId: photo.id,
                    points: [updatedPoint],
                )],
            ),
            previousModelReports: [report.actualModelReport],
        )

        #expect(
            model.remarkPoints(
                for: photo.id,
            ).map(
                \.id,
            ) == [updatedPoint.id],
        )
    }
}
