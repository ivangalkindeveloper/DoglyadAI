import Combine
import DoglyadCamera
import DoglyadNetwork
import DoglyadNeuralModel
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI
import UIKit

@MainActor
final class ScanViewModel: DModuleViewModel<any ScanStateProtocol>, DTextFieldFocusValidatingProtocol, DraftableProtocol {
    @Published var usExaminationType: USExaminationType

    @Published var photos: [USExaminationScanPhoto] = []

    @Published var focus: ScanFocus? = nil

    @NestedObservableObject var examinationNumberTextController = DTextFieldController(
        isRequired: true,
    )

    @NestedObservableObject var patientNameTextController = DTextFieldController(
        isRequired: true,
    )

    @Published var patientGender = PatientGender.male

    @Published var patientDateOfBirth: Date = .init()

    @NestedObservableObject var patientHeightCMTextController: DTextFieldController

    @NestedObservableObject var patientWeightKGTextController: DTextFieldController

    @NestedObservableObject var patientComplaintsTextController = DTextFieldController()

    @NestedObservableObject var examinationDescriptionTextController = DTextFieldController(
        isRequired: true,
    )

    @Published var neuralModel: USExaminationNeuralModel

    @Published var template: USExaminationTemplate?

    let environmentType: EnvironmentType

    private let config: UltrasoundConfig

    private let messager: DMessager
    private let getSelectedTemplate: () -> USExaminationTemplate?
    private let onTemplateSelected: (USExaminationTemplate) async throws -> Void
    private let onTemplateReset: () async throws -> Void
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) async throws -> Void
    let draftAutosaver = DraftAutosaver<USExaminationDraftForm>(
        delay: .seconds(
            1,
        ),
    )
    private var draftPhotosCancellable: AnyCancellable?
    private var draftLifecycleCancellable: AnyCancellable?
    private var cameraController: DCameraControllerFactory.Controller?
    private var examinationObservation: AnyCancellable?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRequestCountIncremented: @escaping () -> Void,
        observeExaminationChanges: @escaping (@escaping () -> Void) -> AnyCancellable,
        getSelectedTemplate: @escaping () -> USExaminationTemplate?,
        onTemplateSelected: @escaping (USExaminationTemplate) async throws -> Void,
        onTemplateReset: @escaping () async throws -> Void,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) async throws -> Void,
    ) {
        self.messager = messager
        self.getSelectedTemplate = getSelectedTemplate
        self.onTemplateSelected = onTemplateSelected
        self.onTemplateReset = onTemplateReset
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected

        neuralModel = getNeuralModel()
        template = getSelectedTemplate()
        environmentType = container.environment.type
        config = container.applicationConfig.ultrasound

        usExaminationType = container.usExaminationTypeDefault
        _patientHeightCMTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldDecimalFormatter(),
                ],
                validators: [
                    DTextFieldDoubleRangeValidator(
                        validRange: Double.leastNonzeroMagnitude ... Double.greatestFiniteMagnitude,
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidPatientHeightDescription,
                            ],
                        ),
                    ),
                ],
            ),
        )
        _patientWeightKGTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldDecimalFormatter(),
                ],
                validators: [
                    DTextFieldDoubleRangeValidator(
                        validRange: Double.leastNonzeroMagnitude ... Double.greatestFiniteMagnitude,
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidPatientWeightDescription,
                            ],
                        ),
                    ),
                ],
            ),
        )

        super.init(
            state: ScanInitializingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .scan,
            ),
        )
        _ = examinationNumberTextController
        _ = patientNameTextController
        _ = patientHeightCMTextController
        _ = patientWeightKGTextController
        _ = patientComplaintsTextController
        _ = examinationDescriptionTextController

        examinationObservation = observeExaminationChanges { [weak self] in
            guard let self else { return }
            neuralModel = getNeuralModel()
            template = getSelectedTemplate()
        }
    }

    var isPhotoLimitReached: Bool { photos.count >= photoMaxCount }
    var isTemplateCompatible: Bool { template.map { $0.usExaminationType.id == usExaminationType.id } ?? true }

    var photoMaxCount: Int { config.scanPhotoMaxNumber }

    var selectedNeuralModelTitle: String { neuralModel.title }

    var defaultPatientDateOfBirth: Date {
        Calendar.current.date(
            byAdding: .year,
            value: -config.defaultPatientDateOfBirthGap,
            to: Date(),
        )!
    }

    var focusList: [DTextFieldFocusValidationItem<ScanFocus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .examinationNumber,
                inputTextController: examinationNumberTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .patientName,
                inputTextController: patientNameTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .patientHeightCM,
                inputTextController: patientHeightCMTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .patientWeightKG,
                inputTextController: patientWeightKGTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .examinationDescription,
                inputTextController: examinationDescriptionTextController,
            ),
        ]
    }

    var isPreviousFieldFocusable: Bool {
        switch focus {
        case .examinationNumber, .none:
            false
        case .patientName, .patientHeightCM, .patientWeightKG, .patientComplaints, .examinationDescription:
            true
        }
    }

    var isNextFieldFocusable: Bool {
        switch focus {
        case .examinationNumber, .patientName, .patientHeightCM, .patientWeightKG, .patientComplaints:
            true
        case .examinationDescription, .none:
            false
        }
    }

    var speechButtonBadge: DButtonBadge? {
        switch subscriptionAvailability(
            of: .formCompletionViaMicrophone,
        ) {
        case .offered:
            DButtonBadge(
                l10n[
                    .subscriptionProLabel,
                ],
                isShimmering: true,
            )
        case .available, .unavailable:
            nil
        }
    }

    var patientAge: Int {
        Calendar.current.dateComponents(
            [.year],
            from: patientDateOfBirth,
            to: Date(),
        ).year ?? 0
    }

    private var ultrasoundConfig: UltrasoundConfig {
        container.applicationConfig.ultrasound
    }

    private var gallerySelectionLimit: Int {
        max(
            photoMaxCount - photos.count,
            0,
        )
    }

    private enum DraftInitializationResult {
        case draft(USExaminationDraft)
        case defaults(reportsCount: Int)
    }

    override func onInit() {
        emit(
            ScanInitializingState(),
        )
        handle {
            if let usExaminationTypeId = try await self.container.ultrasoundReportRepository.getSelectedExaminationTypeId(),
               let storedType = self.container.usExaminationTypesById[
                   usExaminationTypeId,
               ]
            {
                self.usExaminationType = storedType
            }

            let draft = try await self.loadDraft()
            if let draft {
                return DraftInitializationResult.draft(
                    draft,
                )
            }

            let reportsCount = try await self.container.ultrasoundReportRepository.getReportsCount()
            return DraftInitializationResult.defaults(
                reportsCount: reportsCount,
            )
        } onMainSuccess: { result in
            switch result {
            case let .draft(
                draft,
            ):
                self.applyDraft(
                    draft,
                )
            case let .defaults(
                reportsCount,
            ):
                self.applyDefaultValues(
                    reportsCount: reportsCount,
                )
            }
            self.startDraftObservation()
            self.emit(
                ScanDefaultState(),
            )
        } onMainUnknownError: { error in
            self.emit(
                ScanInitializationFailedState(
                    error: error,
                ),
            )
        }
    }

    func onTapRetryInitialization() { onInit() }

    func onTapSettings() {
        analytics.buttonTapped(
            .scanSettings,
        )
        coordinator.screen(
            .settings,
        )
    }

    func onTapUSExaminationType() {
        analytics.buttonTapped(
            .scanUSExaminationType,
        )
        coordinator.sheet(
            .selectUSExaminationType,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: usExaminationType,
                onSelected: { [weak self] selectedType in
                    guard let self else { return }
                    guard usExaminationType != selectedType else { return }

                    try await container.ultrasoundReportRepository.setSelectedExaminationTypeId(
                        id: selectedType.id,
                    )
                    withAnimation(
                        DTheme.light.animation,
                    ) {
                        self.usExaminationType = selectedType
                    }
                },
            ),
        )
    }

    func onTapToolbarUp() {
        switch focus {
        case .examinationNumber, .none:
            break
        case .patientName:
            focus = .examinationNumber
        case .patientHeightCM:
            focus = .patientName
        case .patientWeightKG:
            focus = .patientHeightCM
        case .patientComplaints:
            focus = .patientWeightKG
        case .examinationDescription:
            focus = .patientComplaints
        }
    }

    func onTapToolbarDown() {
        switch focus {
        case .examinationNumber:
            focus = .patientName
        case .patientName:
            focus = .patientHeightCM
        case .patientHeightCM:
            focus = .patientWeightKG
        case .patientWeightKG:
            focus = .patientComplaints
        case .patientComplaints:
            focus = .examinationDescription
        case .examinationDescription, .none:
            break
        }
    }

    func onFocusChanged(
        _ newFocus: ScanFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onTapImport() {
        switch (state, isPhotoLimitReached) {
        case (_ as ScanInitializingState, _), (_ as ScanGeneratingState, _), (_ as ScanLoadingState, _), (_ as ScanClearingState, _), (_, true): return
        default: break
        }

        analytics.buttonTapped(
            .scanImport,
        )
        unfocus()
        coordinator.sheet(
            .importMedia,
            arguments: ImportMediaArguments(
                onTapCamera: { [weak self] in
                    self?.onTapCamera()
                },
                onTapGallery: { [weak self] in
                    self?.onTapGallery()
                },
            ),
        )
    }

    func onTapPhoto(
        _ photo: USExaminationScanPhoto,
    ) {
        coordinator.screen(
            .photoView,
            arguments: PhotoViewArguments(
                getPhotos: { [weak self] in self?.photos ?? [] },
                observePhotos: { [weak self] observer in
                    self?.$photos.sink(
                        receiveValue: observer,
                    ) ?? AnyCancellable {}
                },
                initialPhotoID: photo.id,
                onDelete: { [weak self] photo in
                    self?.onTapDeletePhoto(
                        photo: photo,
                    )
                },
            ),
        )
    }

    func onTapDeletePhoto(
        photo: USExaminationScanPhoto,
    ) {
        guard let index = photos.firstIndex(
            of: photo,
        ) else { return }

        analytics.buttonTapped(
            .scanDeletePhoto,
            parameters: AnalyticsParameters(
                [
                    .itemCount: .int(
                        photos.count,
                    ),
                ],
            ),
        )
        withAnimation {
            _ = self.photos.remove(
                at: index,
            )
        }
    }

    func onTapPatientGender(
        value: PatientGender,
    ) {
        analytics.buttonTapped(
            .scanPatientGender,
        )
        guard patientGender != value else { return }

        patientGender = value
    }

    func onTapPatientDateOfBirth() {
        analytics.buttonTapped(
            .scanPatientDateOfBirth,
        )
        coordinator.sheet(
            .selectDateOfBirth,
            arguments: SelectDateOfBirthArguments(
                currentValue: patientDateOfBirth,
                onSelected: { [weak self] date in
                    guard let self else { return }
                    guard patientDateOfBirth != date else { return }

                    withAnimation(
                        DTheme.light.animation,
                    ) {
                        self.patientDateOfBirth = date
                    }
                },
            ),
        )
    }

    func onSubmit() {
        analytics.buttonTapped(
            .scanSubmit,
        )
        switch focus {
        case .examinationNumber:
            focus = .patientName
        case .patientName:
            focus = .patientHeightCM
        case .patientHeightCM:
            focus = .patientWeightKG
        case .patientWeightKG:
            focus = .patientComplaints
        case .patientComplaints:
            focus = .examinationDescription
        case .examinationDescription, .none:
            focus = nil
        }
    }

    func onTapSelectedTemplate() {
        analytics.buttonTapped(
            .scanSelectedTemplate,
            parameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        getSelectedTemplate() != nil,
                    ),
                ],
            ),
        )
        let usExaminationId = usExaminationType.id
        handle {
            let templates = try await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
            return templates.contains { $0.usExaminationType.id == usExaminationId }
        } onMainSuccess: { [self] hasTemplates in
            guard hasTemplates else {
                return coordinator.screen(
                    .templateAdd,
                    arguments: TemplateAddArguments(
                        onAddSuccess: { [weak self] template in
                            try await self?.onTemplateSelected(
                                template,
                            )
                        },
                    ),
                )
            }

            coordinator.sheet(
                .selectTemplate,
                arguments: SelectTemplateArguments(
                    usExaminationId: usExaminationId,
                    currentValue: getSelectedTemplate(),
                    onSelected: { [weak self] template in
                        try await self?.onTemplateSelected(
                            template,
                        )
                    },
                ),
            )
        }
    }

    func onTapResetTemplate() {
        analytics.buttonTapped(
            .scanResetTemplate,
        )
        handle { try await self.onTemplateReset() } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapNeuralModelSelection() {
        analytics.buttonTapped(
            .scanNeuralModelSelection,
            parameters: AnalyticsParameters(
                [
                    .modelId: .string(
                        getNeuralModel().id,
                    ),
                ],
            ),
        )
        coordinator.sheet(
            .selectNeuralModel,
            arguments: SelectNeuralModelArguments(
                currentValue: getNeuralModel(),
                onSelected: { [weak self] model in
                    try await self?.onNeuralModelSelected(
                        model,
                    )
                },
            ),
        )
    }

    func onTapSettingsAI() {
        analytics.buttonTapped(
            .scanSettingsAI,
        )
        coordinator.screen(
            .settingsAI,
        )
    }

    func onTapClear() {
        switch state {
        case _ as ScanInitializingState, _ as ScanGeneratingState, _ as ScanLoadingState, _ as ScanClearingState, _ as ScanInitializationFailedState: return
        default: break
        }
        analytics.buttonTapped(
            .scanClear,
        )
        let previous = state
        emit(
            ScanClearingState(
                previousState: previous,
            ),
        )
        unfocus()
        handle {
            try await self.clearDraftAndReset()
        } onMainSuccess: { _ in
            self.emit(
                ScanDefaultState(),
            )
        } onMainUnknownError: { _ in
            self.emit(
                previous,
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapFillDevelopment() {
        analytics.buttonTapped(
            .scanFill,
        )
        patientComplaintsTextController.setText(
            container.mockFactory.fillPatientComplaints(
                l10n: container.l10n,
            ),
        )
        examinationDescriptionTextController.setText(
            container.mockFactory.fillExaminationDescription(
                l10n: container.l10n,
            ),
        )
    }

    func onTapSpeech() {
        analytics.buttonTapped(
            .scanSpeech,
        )
        coordinator.run(
            .formCompletionViaMicrophone,
        ) {
            self.startSpeechFlow()
        }
    }

    func onTapScan() {
        switch state {
        case _ as ScanInitializingState, _ as ScanGeneratingState, _ as ScanLoadingState, _ as ScanClearingState, _ as ScanInitializationFailedState: return
        case let state as ScanSaveFailedState:
            unfocus()
            persistReport(
                state.report,
                snapshot: state.snapshot,
            )
            return
        default: break
        }
        analytics.buttonTapped(
            .scanGenerate,
            parameters: AnalyticsParameters(
                [.itemCount: .int(
                    photos.count,
                ), .modelId: .string(
                    getNeuralModel().id,
                )],
            ),
        )
        if let invalidFocus = firstInvalidFocus() { focus = invalidFocus
            return
        }
        unfocus()
        handle {
            try await self.coordinator.prepareReportGeneration()
        } onMainSuccess: { resolution in
            switch resolution {
            case .proceed: self.performScan()
            case .routed: break
            }
        }
    }
}

extension ScanViewModel {
    func loadDraft() async throws -> USExaminationDraft? {
        try await container.ultrasoundDraftRepository.getDraft()
    }

    func applyDraft(
        _ draft: USExaminationDraft,
    ) {
        let draftForm = draft.form
        photos = Array(
            draft.photos.prefix(
                photoMaxCount,
            ),
        )
        examinationNumberTextController.setText(
            draftForm.examinationNumber,
        )
        patientNameTextController.setText(
            draftForm.patientName,
        )
        patientGender = draftForm.patientGender
        patientDateOfBirth = draftForm.patientDateOfBirth
        patientHeightCMTextController.setText(
            draftForm.patientHeightCM,
        )
        patientWeightKGTextController.setText(
            draftForm.patientWeightKG,
        )
        patientComplaintsTextController.setText(
            draftForm.patientComplaints,
        )
        examinationDescriptionTextController.setText(
            draftForm.examinationDescription,
        )
    }

    func clearDraft() async throws {
        try await container.ultrasoundDraftRepository.clearDraft()
    }

    func makeDraftSnapshot() -> USExaminationDraftForm {
        USExaminationDraftForm(
            examinationNumber: examinationNumberTextController.text,
            patientName: patientNameTextController.text,
            patientGender: patientGender,
            patientDateOfBirth: patientDateOfBirth,
            patientHeightCM: patientHeightCMTextController.text,
            patientWeightKG: patientWeightKGTextController.text,
            patientComplaints: patientComplaintsTextController.text,
            examinationDescription: examinationDescriptionTextController.text,
        )
    }

    func saveDraftSnapshot(
        _ draft: USExaminationDraftForm,
    ) async throws {
        try await container.ultrasoundDraftRepository.saveForm(
            draft,
        )
    }

    func onDraftSaveFailed(
        _: Error,
    ) {
        messager.show(
            type: .error,
            title: l10n[
                .scanDraftSaveErrorMessageTitle,
            ],
            description: l10n[
                .scanDraftSaveErrorMessageDescription,
            ],
        )
    }

    func draftChangePublishers() -> [AnyPublisher<Void, Never>] {
        [
            examinationNumberTextController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientNameTextController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            $patientGender
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            $patientDateOfBirth
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientHeightCMTextController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientWeightKGTextController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientComplaintsTextController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            examinationDescriptionTextController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
        ]
    }
}

private extension ScanViewModel {
    func startDraftObservation() {
        startDraftAutosave()

        draftPhotosCancellable = $photos
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] receivedPhotos in
                guard let self else { return }

                saveDraftPhotos(
                    receivedPhotos,
                )
            }

        draftLifecycleCancellable = NotificationCenter.default
            .publisher(
                for: UIApplication.willResignActiveNotification,
            )
            .sink { [weak self] _ in
                self?.saveDraftBeforeBackground()
            }
    }

    func stopDraftObservation() {
        stopDraftAutosave()
        draftPhotosCancellable?.cancel()
        draftPhotosCancellable = nil
        draftLifecycleCancellable?.cancel()
        draftLifecycleCancellable = nil
    }

    func saveDraftPhotos(
        _ draftPhotos: [USExaminationScanPhoto],
    ) {
        let currentForm = makeDraftSnapshot()
        draftAutosaver.enqueue { [weak self] in
            guard let self else { return }

            try await container.ultrasoundDraftRepository.savePhotos(
                draftPhotos,
                currentForm: currentForm,
            )
        }
    }

    func saveDraftBeforeBackground() {
        let backgroundTask = UIApplication.shared.beginBackgroundTask()
        handle {
            self.flushPendingDraftSave()
            try await self.waitForPendingDraftSave()
        } onDefer: {
            guard backgroundTask != .invalid else { return }

            UIApplication.shared.endBackgroundTask(
                backgroundTask,
            )
        }
    }
}

extension ScanViewModel {}

private extension ScanViewModel {
    func onTapCamera() {
        switch (state, isPhotoLimitReached) {
        case (_ as ScanInitializingState, _), (_ as ScanGeneratingState, _), (_ as ScanLoadingState, _), (_ as ScanClearingState, _), (_, true): return
        default: break
        }

        analytics.buttonTapped(
            .scanCamera,
        )
        unfocus()
        handle {
            await self.container.permissionManager.isGranted(
                .camera,
            )
        } onMainSuccess: { [self] isGranted in
            guard isGranted else {
                return coordinator.sheet(
                    .permissionCamera,
                )
            }

            let cameraController = cameraController ?? DCameraControllerFactory.make()
            self.cameraController = cameraController
            coordinator.sheet(
                .scanCamera,
                arguments: ScanCameraArguments(
                    cameraController: cameraController,
                    getPhotos: { [weak self] in
                        self?.photos ?? []
                    },
                    onPhotosUpdated: { [weak self] updatedPhotos in
                        self?.photos = updatedPhotos
                    },
                    photoMaxCount: photoMaxCount,
                ),
            )
        }
    }

    func onTapGallery() {
        switch (state, isPhotoLimitReached) {
        case (_ as ScanInitializingState, _), (_ as ScanGeneratingState, _), (_ as ScanLoadingState, _), (_ as ScanClearingState, _), (_, true): return
        default: break
        }

        analytics.buttonTapped(
            .scanGallery,
            parameters: AnalyticsParameters(
                [
                    .selectionLimit: .int(
                        gallerySelectionLimit,
                    ),
                ],
            ),
        )
        handle {
            await self.container.permissionManager.isGranted(
                .photoLibrary,
            )
        } onMainSuccess: { [self] isGranted in
            guard isGranted else {
                return coordinator.sheet(
                    .permissionPhotoLibrary,
                )
            }

            coordinator.sheet(
                .photoLibraryPicker,
                arguments: PhotoLibraryPickerArguments(
                    selectionLimit: gallerySelectionLimit,
                    onComplete: { [weak self] images in
                        guard let self else { return }

                        onSelectGalleryImages(
                            images,
                        )
                    },
                ),
            )
        }
    }

    func onSelectGalleryImages(
        _ images: [UIImage],
    ) {
        guard photos.count < photoMaxCount else { return }

        let availableCount = photoMaxCount - photos.count
        Task {
            var newPhotos: [USExaminationScanPhoto] = []
            for image in images.prefix(
                availableCount,
            ) {
                await newPhotos.append(
                    USExaminationScanPhoto.make(
                        image: image,
                    ),
                )
            }

            withAnimation {
                self.photos.append(
                    contentsOf: newPhotos,
                )
            }
        }
    }

    func startSpeechFlow() {
        handle {
            await self.container.permissionManager.isGranted(
                .microphone,
            )
        } onMainSuccess: { [self] isGranted in
            if !isGranted {
                return coordinator.sheet(
                    .permissionSpeech,
                )
            }

            let examinationType = usExaminationType
            coordinator.sheet(
                .scanSpeech,
                arguments: ScanSpeechArguments(
                    examinationType: examinationType,
                    onConfirm: { [weak self] proposals in
                        guard let self, usExaminationType.id == examinationType.id,
                              let updatedForm = ScanFormPatch.apply(
                                  proposals,
                                  to: makeDraftSnapshot(),
                              )
                        else { return false }
                        applyDraft(
                            USExaminationDraft(
                                form: updatedForm,
                                photos: photos,
                            ),
                        )
                        return true
                    },
                ),
            )
        }
    }

    func performScan() {
        switch state {
        case _ as ScanInitializingState, _ as ScanGeneratingState, _ as ScanLoadingState, _ as ScanClearingState, _ as ScanInitializationFailedState: return
        case let state as ScanSaveFailedState:
            persistReport(
                state.report,
                snapshot: state.snapshot,
            )
            return
        default: break
        }

        guard let number = examinationNumberTextController.value,
              let patientName = patientNameTextController.value,
              let description = examinationDescriptionTextController.value else { return }
        let snapshot = makeDraftSnapshot()
        let examinationData = USExaminationData(
            usExaminationTypeId: usExaminationType.id,
            photos: photos,
            examinationNumber: number,
            patientName: patientName,
            patientGender: patientGender,
            patientDateOfBirth: patientDateOfBirth,
            patientHeight: patientHeightCMTextController.value.flatMap(
                Double.init,
            ),
            patientWeight: patientWeightKGTextController.value.flatMap(
                Double.init,
            ),
            patientComplaints: patientComplaintsTextController.value,
            examinationDescription: description,
        )
        let settings = settingsAI
        let template = getSelectedTemplate()?.content
        emit(
            ScanGeneratingState(
                snapshot: snapshot,
            ),
        )
        handle {
            let request = try await USExaminationRequest(
                settingsAI: settings,
                examinationData: examinationData,
                template: template,
                isRecommendationsIncluded: self.container.userSettingsRepository.getIsRecommendationsIncluded(),
                isPhotoRemarks: self.container.userSettingsRepository.getIsPhotoRemarks(),
                isDescriptionRemarks: self.container.userSettingsRepository.getIsDescriptionRemarks(),
            )
            let response = try await self.container.ultrasoundReportRepository.generateReport(
                locale: self.container.language.currentLocale,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: self.ultrasoundConfig.scanPhotoResizeMaxDimension,
                    compressionQuality: self.ultrasoundConfig.scanPhotoCompressionQuality,
                ),
            )
            return USExaminationReport(
                date: Date(),
                settingsAI: settings,
                examinationData: examinationData,
                actualModelReport: response,
                previousModelReports: [],
            )
        } onMainSuccess: { report in
            self.persistReport(
                report,
                snapshot: snapshot,
            )
        } onMainApiError: { error in self.onGenerationFailed(
            error,
        ) }
        onMainConnectionError: { error in self.onGenerationFailed(
            error,
        ) }
        onMainUnknownError: { error in self.onGenerationFailed(
            error,
        ) }
    }

    func persistReport(
        _ report: USExaminationReport,
        snapshot: USExaminationDraftForm,
    ) {
        emit(
            ScanLoadingState(
                report: report,
                snapshot: snapshot,
            ),
        )
        handle {
            try await self.container.ultrasoundReportRepository.setReport(
                report: report,
            )
            self.incrementRequestCount()
            if snapshot == self.makeDraftSnapshot(), report.examinationData.photos.map(
                \.id,
            ) == self.photos.map(
                \.id,
            ) {
                do { try await self.clearDraftAndReset() }
                catch { self.onDraftSaveFailed(
                    error,
                ) }
            }
        } onMainSuccess: { _ in
            self.emit(
                ScanDefaultState(),
            )
            self.coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedArguments(
                    report: report,
                ),
            )
        } onMainUnknownError: { error in
            self.emit(
                ScanSaveFailedState(
                    report: report,
                    snapshot: snapshot,
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onGenerationFailed(
        _ error: Error,
    ) {
        emit(
            ScanFailedState(
                error: error,
            ),
        )
        messager.showUnknownError(
            l10n: l10n,
        )
    }

    func clearDraftAndReset() async throws {
        stopDraftObservation()
        defer { startDraftObservation() }
        let reportsCount = try await container.ultrasoundReportRepository.getReportsCount()
        try await waitForPendingDraftSave()
        try await clearDraft()
        applyDefaultValues(
            reportsCount: reportsCount,
        )
    }

    func applyDefaultValues(
        reportsCount: Int,
    ) {
        photos.removeAll()
        examinationNumberTextController.setText(
            String(
                localized: container.l10n.resource(
                    .scanExaminationDefaultNumberLabel,
                    values: ["count": String(
                        reportsCount,
                    )],
                ),
            ),
        )
        patientNameTextController.setText(
            String(
                localized: container.l10n.resource(
                    .scanPatientDefaultNameLabel,
                    values: ["count": String(
                        reportsCount,
                    )],
                ),
            ),
        )
        patientGender = .male
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMTextController.clear()
        patientWeightKGTextController.clear()
        patientComplaintsTextController.clear()
        examinationDescriptionTextController.clear()
    }

    func clearForm() {
        photos.removeAll()
        examinationNumberTextController.clear()
        patientNameTextController.clear()
        patientGender = .male
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMTextController.clear()
        patientWeightKGTextController.clear()
        patientComplaintsTextController.clear()
        examinationDescriptionTextController.clear()
    }
}
