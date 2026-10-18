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

    @NestedObservableObject var examinationNumberController = DTextFieldController(
        isRequired: true,
    )

    @NestedObservableObject var patientNameController = DTextFieldController(
        isRequired: true,
    )

    @Published var patientGender = PatientGender.male

    @Published var patientDateOfBirth: Date = .init()

    @NestedObservableObject var patientHeightCMController: DTextFieldController

    @NestedObservableObject var patientWeightKGController: DTextFieldController

    @NestedObservableObject var patientComplaintsController = DTextFieldController()

    @NestedObservableObject var examinationDescriptionController = DTextFieldController(
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
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
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
        _patientHeightCMController = NestedObservableObject(
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
        _patientWeightKGController = NestedObservableObject(
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
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .scan,
            ),
        )
        _ = examinationNumberController
        _ = patientNameController
        _ = patientHeightCMController
        _ = patientWeightKGController
        _ = patientComplaintsController
        _ = examinationDescriptionController

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
                controller: examinationNumberController,
            ),
            DTextFieldFocusValidationItem(
                focus: .patientName,
                controller: patientNameController,
            ),
            DTextFieldFocusValidationItem(
                focus: .patientHeightCM,
                controller: patientHeightCMController,
            ),
            DTextFieldFocusValidationItem(
                focus: .patientWeightKG,
                controller: patientWeightKGController,
            ),
            DTextFieldFocusValidationItem(
                focus: .examinationDescription,
                controller: examinationDescriptionController,
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

    func onTapNeuralModelSettings() {
        analytics.buttonTapped(
            .scanNeuralModelSettings,
        )
        coordinator.run(
            .neuralModelSettings,
        ) {
            self.coordinator.screen(
                .neuralModelSettings,
            )
        }
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
        patientComplaintsController.setText(
            container.mockFactory.fillPatientComplaints(
                l10n: container.l10n,
            ),
        )
        examinationDescriptionController.setText(
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
        examinationNumberController.setText(
            draftForm.examinationNumber,
        )
        patientNameController.setText(
            draftForm.patientName,
        )
        patientGender = draftForm.patientGender
        patientDateOfBirth = draftForm.patientDateOfBirth
        patientHeightCMController.setText(
            draftForm.patientHeightCM,
        )
        patientWeightKGController.setText(
            draftForm.patientWeightKG,
        )
        patientComplaintsController.setText(
            draftForm.patientComplaints,
        )
        examinationDescriptionController.setText(
            draftForm.examinationDescription,
        )
    }

    func clearDraft() async throws {
        try await container.ultrasoundDraftRepository.clearDraft()
    }

    func makeDraftSnapshot() -> USExaminationDraftForm {
        USExaminationDraftForm(
            examinationNumber: examinationNumberController.text,
            patientName: patientNameController.text,
            patientGender: patientGender,
            patientDateOfBirth: patientDateOfBirth,
            patientHeightCM: patientHeightCMController.text,
            patientWeightKG: patientWeightKGController.text,
            patientComplaints: patientComplaintsController.text,
            examinationDescription: examinationDescriptionController.text,
        )
    }

    func currentVoiceFieldValue(
        _ id: DNeuralUltrasoundVoiceFieldId,
    ) -> String {
        switch id {
        case .examinationNumber: examinationNumberController.text
        case .patientName: patientNameController.text
        case .patientGender:
            switch patientGender {
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
        case .patientDateOfBirth: patientDateOfBirth.formatted(
                Date.FormatStyle(
                    date: .abbreviated,
                    time: .omitted,
                ).locale(
                    l10n.locale,
                ),
            )
        case .patientHeightCM: patientHeightCMController.text
        case .patientWeightKG: patientWeightKGController.text
        case .patientComplaints: patientComplaintsController.text
        case .examinationDescription: examinationDescriptionController.text
        }
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
            examinationNumberController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientNameController.$text
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
            patientHeightCMController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientWeightKGController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            patientComplaintsController.$text
                .dropFirst()
                .map { _ in () }
                .eraseToAnyPublisher(),
            examinationDescriptionController.$text
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
                    getCurrentValue: { [weak self] fieldId in
                        self?.currentVoiceFieldValue(
                            fieldId,
                        ) ?? ""
                    },
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

        guard let number = examinationNumberController.value,
              let patientName = patientNameController.value,
              let description = examinationDescriptionController.value else { return }
        let snapshot = makeDraftSnapshot()
        let examinationData = USExaminationData(
            usExaminationTypeId: usExaminationType.id,
            photos: photos,
            examinationNumber: number,
            patientName: patientName,
            patientGender: patientGender,
            patientDateOfBirth: patientDateOfBirth,
            patientHeight: patientHeightCMController.value.flatMap(
                Double.init,
            ),
            patientWeight: patientWeightKGController.value.flatMap(
                Double.init,
            ),
            patientComplaints: patientComplaintsController.value,
            examinationDescription: description,
        )
        let settings = neuralModelSettings
        let template = getSelectedTemplate()?.content
        emit(
            ScanGeneratingState(
                snapshot: snapshot,
            ),
        )
        handle {
            let request = try await USExaminationRequest(
                neuralModelSettings: settings,
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
                neuralModelSettings: settings,
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
        examinationNumberController.setText(
            String(
                localized: container.l10n.resource(
                    .scanExaminationDefaultNumberLabel,
                    values: ["count": String(
                        reportsCount,
                    )],
                ),
            ),
        )
        patientNameController.setText(
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
        patientHeightCMController.clear()
        patientWeightKGController.clear()
        patientComplaintsController.clear()
        examinationDescriptionController.clear()
    }

    func clearForm() {
        photos.removeAll()
        examinationNumberController.clear()
        patientNameController.clear()
        patientGender = .male
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMController.clear()
        patientWeightKGController.clear()
        patientComplaintsController.clear()
        examinationDescriptionController.clear()
    }
}
