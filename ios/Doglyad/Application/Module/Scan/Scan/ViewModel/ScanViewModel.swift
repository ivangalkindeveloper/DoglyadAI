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
    @NestedObservableObject var examinationNumberTextController: DTextFieldController
    @NestedObservableObject var patientNameTextController: DTextFieldController
    @Published var patientGender = PatientGender.male
    @Published var patientDateOfBirth: Date = .init()
    @NestedObservableObject var patientHeightCMTextController: DTextFieldController
    @NestedObservableObject var patientWeightKGTextController: DTextFieldController
    @NestedObservableObject var patientComplaintsTextController: DTextFieldController
    @NestedObservableObject var examinationDescriptionTextController: DTextFieldController
    @Published var isPatientPreparedForExamination = true
    @Published var neuralModel: USExaminationNeuralModel
    @Published var template: USExaminationTemplate?
    let environmentType: EnvironmentType
    private let config: UltrasoundConfig
    private(set) var draftRestorationTask: Task<Void, Never>?
    private var draftRestorationChangedFields = Set<PartialKeyPath<ScanViewModel>>()
    private var draftRestorationCancellables = Set<AnyCancellable>()
    private let messager: DMessager
    private let observeExaminationChanges: (@escaping () -> Void) -> AnyCancellable
    private let getSelectedTemplate: () -> USExaminationTemplate?
    private let onTemplateSelected: (USExaminationTemplate) async throws -> Void
    private let onTemplateReset: () async throws -> Void
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) async throws -> Void
    private let onStartReportGeneration: (USExaminationRequest) async throws -> USExaminationReport
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
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        observeExaminationChanges: @escaping (@escaping () -> Void) -> AnyCancellable,
        getSelectedTemplate: @escaping () -> USExaminationTemplate?,
        onTemplateSelected: @escaping (USExaminationTemplate) async throws -> Void,
        onTemplateReset: @escaping () async throws -> Void,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) async throws -> Void,
        onStartReportGeneration: @escaping (USExaminationRequest) async throws -> USExaminationReport,
    ) {
        usExaminationType = container.usExaminationTypeDefault

        _examinationNumberTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                isRequired: true,
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scan.examinationNumberMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scan.examinationNumberMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scan.examinationNumberMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        _patientNameTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                isRequired: true,
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scan.patientNameMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scan.patientNameMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scan.patientNameMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        _patientHeightCMTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldDecimalFormatter(),
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scan.patientHeightCMMaxLength,
                    ),
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
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scan.patientHeightCMMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scan.patientHeightCMMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        _patientWeightKGTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldDecimalFormatter(),
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scan.patientWeightKGMaxLength,
                    ),
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
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scan.patientWeightKGMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scan.patientWeightKGMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        _patientComplaintsTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scan.patientComplaintsMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scan.patientComplaintsMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scan.patientComplaintsMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        _examinationDescriptionTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                isRequired: true,
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.scan.examinationDescriptionMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.scan.examinationDescriptionMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.scan.examinationDescriptionMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )

        neuralModel = getNeuralModel()
        template = getSelectedTemplate()
        environmentType = container.environment.type
        config = container.applicationConfig.ultrasound
        self.messager = messager
        self.observeExaminationChanges = observeExaminationChanges
        self.getSelectedTemplate = getSelectedTemplate
        self.onTemplateSelected = onTemplateSelected
        self.onTemplateReset = onTemplateReset
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected
        self.onStartReportGeneration = onStartReportGeneration

        super.init(
            state: ScanInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
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
    }

    var isPhotoLimitReached: Bool {
        photos.count >= photoMaxCount
    }

    var isTemplateCompatible: Bool {
        template.map {
            $0.usExaminationType.id == usExaminationType.id
        } ?? true
    }

    var photoMaxCount: Int {
        config.scanPhotoMaxNumber
    }

    var selectedNeuralModelTitle: String {
        neuralModel.title
    }

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
                focus: .patientComplaints,
                inputTextController: patientComplaintsTextController,
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
        case defaults(reportsCount: Int?)
    }

    override func onInit() {
        examinationObservation = observeExaminationChanges { [weak self] in
            guard let self else {
                return
            }
            neuralModel = getNeuralModel()
            template = getSelectedTemplate()
        }
        startDraftLifecycleObservation()
        loadInitialDraft()
    }

    func onBackground() {
        let backgroundTask = UIApplication.shared.beginBackgroundTask()
        handle {
            await self.draftRestorationTask?.value
            await self.operationTask?.value
            self.flushPendingDraftSave()
            try await self.waitForPendingDraftSave()
        } onDefer: {
            guard backgroundTask != .invalid else {
                return
            }

            UIApplication.shared.endBackgroundTask(
                backgroundTask,
            )
        }
    }

    func onResume() {
        #if DEBUG
            guard !isPreviewSnapshot else {
                return
            }
        #endif
        switch state {
        case _ as ScanInitializationErrorState: loadInitialDraft()
        default: break
        }
    }

    func onTapSettings() {
        analytics.buttonTapped(
            .scanSettings,
        )
        coordinator.screen(
            .menu,
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
                    guard let self else {
                        return
                    }
                    guard usExaminationType != selectedType else {
                        return
                    }

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
        case (_ as ScanGenerationLoadingState, _), (_, true): return
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
                getPhotos: { [weak self] in
                    self?.photos ?? []
                },
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
        ) else {
            return
        }

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
        guard patientGender != value else {
            return
        }

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
                    guard let self else {
                        return
                    }
                    guard patientDateOfBirth != date else {
                        return
                    }

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

    func togglePatientPreparedForExamination() {
        isPatientPreparedForExamination.toggle()
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
            return templates.filter {
                $0.usExaminationType.id == usExaminationId
            }
        } onMainSuccess: { [self] templates in
            guard !templates.isEmpty else {
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
                    templates: templates,
                    currentValue: getSelectedTemplate(),
                    onSelected: { [weak self] template in
                        try await self?.onTemplateSelected(
                            template,
                        )
                    },
                ),
            )
        } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapResetTemplate() {
        analytics.buttonTapped(
            .scanResetTemplate,
        )
        handle {
            try await self.onTemplateReset()
        } onMainUnknownError: { _ in
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
        case _ as ScanGenerationLoadingState: return
        default: break
        }
        analytics.buttonTapped(
            .scanClear,
        )
        let previous = state
        stopDraftRestoration()

        unfocus()
        performLocalOperation {
            try await self.clearDraftAndReset()
        } onSuccess: { _ in
            self.emit(
                ScanInitialState(),
            )
        } onFailure: { _ in
            self.emit(
                previous,
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    func onTapFillDevelopment() {
        switch state {
        case _ as ScanGenerationLoadingState: return
        default: break
        }
        analytics.buttonTapped(
            .scanFill,
        )
        guard let examinationType = container.getUSExaminationTypeById(
            id: container.mockFactory.examinationTypeId,
        ) else {
            messager.showUnknownError(
                l10n: l10n,
            )
            return
        }
        handle {
            try await self.container.ultrasoundReportRepository.setSelectedExaminationTypeId(
                id: examinationType.id,
            )
        } onMainSuccess: { _ in
            self.usExaminationType = examinationType
            self.patientComplaintsTextController.setText(
                self.container.mockFactory.fillPatientComplaints(
                    l10n: self.l10n,
                ),
            )
            self.examinationDescriptionTextController.setText(
                self.container.mockFactory.fillExaminationDescription(
                    l10n: self.l10n,
                ),
            )
        } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
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
        guard operationTask == nil else {
            return
        }
        switch state {
        case _ as ScanGenerationLoadingState: return
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
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }
        if draftRestorationTask != nil || !draftRestorationCancellables.isEmpty {
            stopDraftRestoration()
            startDraftObservation()
            saveCurrentDraft(
                isPhotosChanged: true,
            )
        }
        unfocus()
        performLocalOperation {
            try await self.container.userSettingsRepository.getIsNeedPatientConsent()
        } onSuccess: { isNeedPatientConsent in
            if isNeedPatientConsent {
                self.coordinator.sheet(
                    .patientConsent,
                    arguments: PatientConsentArguments(
                        onConfirm: { [weak self] in
                            self?.prepareReportGeneration()
                        },
                    ),
                )
            } else {
                self.prepareReportGeneration()
            }
        } onFailure: { _ in
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

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
        examinationNumberTextController.restoreText(
            draftForm.examinationNumber,
        )
        patientNameTextController.restoreText(
            draftForm.patientName,
        )
        patientGender = draftForm.patientGender
        patientDateOfBirth = draftForm.patientDateOfBirth
        patientHeightCMTextController.restoreText(
            draftForm.patientHeightCM,
        )
        patientWeightKGTextController.restoreText(
            draftForm.patientWeightKG,
        )
        patientComplaintsTextController.restoreText(
            draftForm.patientComplaints,
        )
        examinationDescriptionTextController.restoreText(
            draftForm.examinationDescription,
        )
        isPatientPreparedForExamination = draftForm.isPatientPreparedForExamination
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
            isPatientPreparedForExamination: isPatientPreparedForExamination,
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
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            patientNameTextController.$text
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            $patientGender
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            $patientDateOfBirth
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            patientHeightCMTextController.$text
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            patientWeightKGTextController.$text
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            patientComplaintsTextController.$text
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            examinationDescriptionTextController.$text
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
            $isPatientPreparedForExamination
                .dropFirst()
                .map { _ in
                    ()
                }
                .eraseToAnyPublisher(),
        ]
    }

    private func loadInitialDraft() {
        guard draftRestorationTask == nil else {
            return
        }
        trackDraftRestorationChanges()
        emit(
            ScanInitialState(),
        )
        draftRestorationTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let typeID = try await container.ultrasoundReportRepository.getSelectedExaminationTypeId()
                let draft = try await loadDraft()
                let result: DraftInitializationResult = if let draft {
                    .draft(
                        draft,
                    )
                } else {
                    await .defaults(
                        reportsCount: try? container.ultrasoundReportRepository.getReportsCount(),
                    )
                }
                guard !Task.isCancelled else {
                    return
                }
                draftRestorationCancellables.removeAll()
                applyInitialDraft(
                    result,
                    typeID: typeID,
                )
                let isEdited = !draftRestorationChangedFields.isEmpty
                let isPhotosChanged = draftRestorationChangedFields.contains(
                    \.photos,
                )
                draftRestorationChangedFields.removeAll()
                draftRestorationTask = nil
                startDraftObservation()
                if isEdited {
                    saveCurrentDraft(
                        isPhotosChanged: isPhotosChanged,
                    )
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                draftRestorationTask = nil
                // Keep the original stored draft intact until a successful read or an explicit main action.
                emit(
                    ScanInitializationErrorState(
                        error: error,
                    ),
                )
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
        }
    }

    private func trackDraftRestorationChanges() {
        guard draftRestorationCancellables.isEmpty else {
            return
        }
        let fields: [(PartialKeyPath<ScanViewModel>, AnyPublisher<Void, Never>)] = [
            (\.examinationNumberTextController, examinationNumberTextController.$text.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.patientNameTextController, patientNameTextController.$text.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.patientGender, $patientGender.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.patientDateOfBirth, $patientDateOfBirth.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.patientHeightCMTextController, patientHeightCMTextController.$text.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.patientWeightKGTextController, patientWeightKGTextController.$text.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.patientComplaintsTextController, patientComplaintsTextController.$text.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.examinationDescriptionTextController, examinationDescriptionTextController.$text.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.isPatientPreparedForExamination, $isPatientPreparedForExamination.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.photos, $photos.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
            (\.usExaminationType, $usExaminationType.dropFirst().map { _ in
                ()
            }.eraseToAnyPublisher()),
        ]
        for (field, publisher) in fields {
            publisher.sink { [weak self] _ in
                self?.draftRestorationChangedFields.insert(
                    field,
                )
            }.store(
                in: &draftRestorationCancellables,
            )
        }
    }

    private func applyInitialDraft(
        _ result: DraftInitializationResult,
        typeID: String?,
    ) {
        let form: USExaminationDraftForm?
        switch result {
        case let .draft(
            draft,
        ):
            form = draft.form
            if !draftRestorationChangedFields.contains(
                \.photos,
            ) {
                photos = Array(
                    draft.photos.prefix(
                        photoMaxCount,
                    ),
                )
            }
        case let .defaults(
            reportsCount,
        ):
            form = reportsCount.map { count in
                USExaminationDraftForm(
                    examinationNumber: l10n.text(
                        .scanExaminationDefaultNumberLabel,
                        values: [.count: String(
                            count,
                        )],
                    ),
                    patientName: l10n.text(
                        .scanPatientDefaultNameLabel,
                        values: [.count: String(
                            count,
                        )],
                    ),
                    patientGender: .male,
                    patientDateOfBirth: defaultPatientDateOfBirth,
                    patientHeightCM: "",
                    patientWeightKG: "",
                    patientComplaints: "",
                    examinationDescription: "",
                    isPatientPreparedForExamination: true,
                )
            }
        }
        if !draftRestorationChangedFields.contains(
            \.usExaminationType,
        ), let typeID, let type = container.usExaminationTypesById[
            typeID,
        ] {
            usExaminationType = type
        }
        guard let form else {
            return
        }
        let textFields: [(PartialKeyPath<ScanViewModel>, DTextFieldController, String)] = [
            (\.examinationNumberTextController, examinationNumberTextController, form.examinationNumber),
            (\.patientNameTextController, patientNameTextController, form.patientName),
            (\.patientHeightCMTextController, patientHeightCMTextController, form.patientHeightCM),
            (\.patientWeightKGTextController, patientWeightKGTextController, form.patientWeightKG),
            (\.patientComplaintsTextController, patientComplaintsTextController, form.patientComplaints),
            (\.examinationDescriptionTextController, examinationDescriptionTextController, form.examinationDescription),
        ]
        for (field, inputTextController, value) in textFields where !draftRestorationChangedFields.contains(
            field,
        ) {
            inputTextController.restoreText(
                value,
            )
        }
        if !draftRestorationChangedFields.contains(
            \.patientGender,
        ) {
            patientGender = form.patientGender
        }
        if !draftRestorationChangedFields.contains(
            \.patientDateOfBirth,
        ) {
            patientDateOfBirth = form.patientDateOfBirth
        }
        if !draftRestorationChangedFields.contains(
            \.isPatientPreparedForExamination,
        ) {
            isPatientPreparedForExamination = form.isPatientPreparedForExamination
        }
    }

    private func stopDraftRestoration() {
        draftRestorationTask?.cancel()
        draftRestorationTask = nil
        draftRestorationCancellables.removeAll()
        draftRestorationChangedFields.removeAll()
    }

    private func saveCurrentDraft(
        isPhotosChanged: Bool,
    ) {
        let form = makeDraftSnapshot()
        let currentPhotos = photos
        draftAutosaver.enqueue { [weak self] in
            guard let self else {
                return
            }
            try await saveDraftSnapshot(
                form,
            )
            if isPhotosChanged {
                try await container.ultrasoundDraftRepository.savePhotos(
                    currentPhotos,
                    currentForm: form,
                )
            }
        }
    }

    private func startDraftObservation() {
        startDraftAutosave()

        draftPhotosCancellable = $photos
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] receivedPhotos in
                guard let self else {
                    return
                }

                saveDraftPhotos(
                    receivedPhotos,
                )
            }

        startDraftLifecycleObservation()
    }

    private func startDraftLifecycleObservation() {
        guard draftLifecycleCancellable == nil else {
            return
        }
        draftLifecycleCancellable = NotificationCenter.default
            .publisher(
                for: UIApplication.willResignActiveNotification,
            )
            .sink { [weak self] _ in
                self?.onBackground()
            }
    }

    private func stopDraftObservation() {
        stopDraftAutosave()
        draftPhotosCancellable?.cancel()
        draftPhotosCancellable = nil
    }

    private func saveDraftPhotos(
        _ draftPhotos: [USExaminationScanPhoto],
    ) {
        let currentForm = makeDraftSnapshot()
        draftAutosaver.enqueue { [weak self] in
            guard let self else {
                return
            }

            try await container.ultrasoundDraftRepository.savePhotos(
                draftPhotos,
                currentForm: currentForm,
            )
        }
    }

    private func onTapCamera() {
        switch (state, isPhotoLimitReached) {
        case (_ as ScanGenerationLoadingState, _), (_, true): return
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

    private func onTapGallery() {
        switch (state, isPhotoLimitReached) {
        case (_ as ScanGenerationLoadingState, _), (_, true): return
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
                        guard let self else {
                            return
                        }

                        onSelectGalleryImages(
                            images,
                        )
                    },
                ),
            )
        }
    }

    private func onSelectGalleryImages(
        _ images: [UIImage],
    ) {
        guard photos.count < photoMaxCount else {
            return
        }

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

    private func startSpeechFlow() {
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
                        else {
                            return false
                        }
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

    private func prepareReportGeneration() {
        handle {
            try await self.coordinator.prepareReportGeneration()
        } onMainSuccess: { resolution in
            switch resolution {
            case .proceed: self.performScan()
            case .routed: break
            }
        }
    }

    private func performScan() {
        guard operationTask == nil else {
            return
        }
        switch state {
        case _ as ScanGenerationLoadingState: return
        default: break
        }

        guard let number = examinationNumberTextController.value,
              let patientName = patientNameTextController.value,
              let description = examinationDescriptionTextController.value
        else {
            return
        }
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
            isPatientPreparedForExamination: isPatientPreparedForExamination,
            isPatientConsent: true,
        )
        let settings = settingsAI
        let template = getSelectedTemplate()?.content
        emit(
            ScanGenerationLoadingState(
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
            return try await self.onStartReportGeneration(
                request,
            )
        } onMainSuccess: { report in
            self.finishScan(
                report,
                snapshot: snapshot,
            )
        } onMainApiError: { error in
            self.onGenerationFailed(
                error,
            )
        }
        onMainConnectionError: { error in
            self.onGenerationFailed(
                error,
            )
        }
        onMainUnknownError: { error in
            self.onGenerationFailed(
                error,
            )
        }
    }

    private func finishScan(
        _ report: USExaminationReport,
        snapshot: USExaminationDraftForm,
    ) {
        handle {
            if snapshot == self.makeDraftSnapshot(), report.examinationData.photos.map(
                \.id,
            ) == self.photos.map(
                \.id,
            ) {
                do {
                    try await self.clearDraftAndReset()
                } catch {
                    self.onDraftSaveFailed(
                        error,
                    )
                }
            }
        } onMainSuccess: { _ in
            self.emit(
                ScanInitialState(),
            )
            self.coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedArguments(
                    report: report,
                ),
            )
        } onMainUnknownError: { error in
            self.onGenerationFailed(
                error,
            )
        }
    }

    private func onGenerationFailed(
        _ error: Error,
    ) {
        emit(
            ScanErrorState(
                error: error,
            ),
        )
        messager.showUnknownError(
            l10n: l10n,
        )
    }

    private func clearDraftAndReset() async throws {
        stopDraftObservation()
        trackDraftRestorationChanges()
        defer {
            let isEdited = !draftRestorationChangedFields.isEmpty
            draftRestorationCancellables.removeAll()
            draftRestorationChangedFields.removeAll()
            startDraftObservation()
            if isEdited {
                saveCurrentDraft(
                    isPhotosChanged: true,
                )
            }
        }
        try await waitForPendingDraftSave()
        try await clearDraft()
        let reportsCount = try await container.ultrasoundReportRepository.getReportsCount()
        draftRestorationCancellables.removeAll()
        applyInitialDraft(
            .defaults(
                reportsCount: reportsCount,
            ),
            typeID: nil,
        )
        if !draftRestorationChangedFields.contains(
            \.photos,
        ) {
            photos.removeAll()
        }
    }

    private func clearForm() {
        photos.removeAll()
        examinationNumberTextController.clear()
        patientNameTextController.clear()
        patientGender = .male
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMTextController.clear()
        patientWeightKGTextController.clear()
        patientComplaintsTextController.clear()
        examinationDescriptionTextController.clear()
        isPatientPreparedForExamination = true
    }
}
