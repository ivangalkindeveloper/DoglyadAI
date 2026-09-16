import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ScanViewModel: DViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case examinationNumber
        case patientName
        case patientHeightCM
        case patientWeightKG
        case patientComplaints
        case examinationDescription
    }

    private let messager: DMessager
    private let getSelectedTemplate: () -> USExaminationTemplate?
    private let onTemplateSelected: (USExaminationTemplate) -> Void
    private let onTemplateReset: () -> Void
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        getSelectedTemplate: @escaping () -> USExaminationTemplate?,
        onTemplateSelected: @escaping (USExaminationTemplate) -> Void,
        onTemplateReset: @escaping () -> Void,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.messager = messager
        self.getSelectedTemplate = getSelectedTemplate
        self.onTemplateSelected = onTemplateSelected
        self.onTemplateReset = onTemplateReset
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected
        usExaminationType = container.usExaminationTypeDefault
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.scan)
        )
    }

    private var ultrasoundConfig: UltrasoundConfig {
        container.applicationConfig.ultrasound
    }

    var photoMaxCount: Int {
        ultrasoundConfig.scanPhotoMaxNumber
    }

    private var defaultPatientDateOfBirth: Date {
        Calendar.current.date(byAdding: .year, value: -ultrasoundConfig.defaultPatientDateOfBirthGap, to: Date())!
    }

    private var defaultPatientHeightCM: Double {
        ultrasoundConfig.defaultPatientHeightCM
    }

    private var defaultPatientWeightKG: Double {
        ultrasoundConfig.defaultPatientWeightKG
    }

    @Published var usExaminationType: USExaminationType
    @Published var photos: [USExaminationScanPhoto] = []
    //
    @Published var focus: Focus? = nil
    @NestedObservableObject var examinationNumberController = DTextFieldController(isRequired: true)
    @NestedObservableObject var patientNameController = DTextFieldController(isRequired: true)
    @Published var patientGender = PatientGender.male
    @Published var patientDateOfBirth: Date = .init()
    @NestedObservableObject var patientHeightCMController = DTextFieldController(
        isRequired: true,
        formatters: [
            DTextFieldDecimalFormatter(),
        ],
        validators: [
            DTextFieldDoubleRangeValidator(
                validRange: Double.leastNonzeroMagnitude ... Double.greatestFiniteMagnitude,
                invalidValueErrorText: String(localized: .errorInvalidPatientHeight)
            ),
        ]
    )
    @NestedObservableObject var patientWeightKGController = DTextFieldController(
        isRequired: true,
        formatters: [
            DTextFieldDecimalFormatter(),
        ],
        validators: [
            DTextFieldDoubleRangeValidator(
                validRange: Double.leastNonzeroMagnitude ... Double.greatestFiniteMagnitude,
                invalidValueErrorText: String(localized: .errorInvalidPatientWeight)
            ),
        ]
    )
    @NestedObservableObject var patientComplaintsController = DTextFieldController()
    @NestedObservableObject var examinationDescriptionController = DTextFieldController(isRequired: true)
    //
    @Published var isLoading = false

    var focusList: [DTextFieldFocusValidationItem<Focus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .examinationNumber,
                controller: examinationNumberController
            ),
            DTextFieldFocusValidationItem(
                focus: .patientName,
                controller: patientNameController
            ),
            DTextFieldFocusValidationItem(
                focus: .patientHeightCM,
                controller: patientHeightCMController
            ),
            DTextFieldFocusValidationItem(
                focus: .patientWeightKG,
                controller: patientWeightKGController
            ),
            DTextFieldFocusValidationItem(
                focus: .examinationDescription,
                controller: examinationDescriptionController
            ),
        ]
    }

    override func onInit() {
        if let usExaminationTypeId = container.ultrasoundReportRepository.getSelectedExaminationTypeId(),
           let usExaminationType = container.usExaminationTypesById[usExaminationTypeId]
        {
            self.usExaminationType = usExaminationType
        }
        handle {
            await self.container.ultrasoundReportRepository.getReportsCount()
        } onMainSuccess: { reportsCount in
            self.examinationNumberController.setText(
                String(localized: .scanExaminationDefaultNumberLabel(count: reportsCount))
            )
            self.patientNameController.setText(
                String(localized: .scanPatientDefaultNameLabel(count: reportsCount))
            )
        }
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMController.setText(String(defaultPatientHeightCM))
        patientWeightKGController.setText(String(defaultPatientWeightKG))
    }

    var isPhotoFilling: Bool {
        photos.count == photoMaxCount
    }

    func unfocus() {
        focus = nil
    }

    var canFocusPreviousField: Bool {
        switch focus {
        case .examinationNumber, .none:
            false
        case .patientName, .patientHeightCM, .patientWeightKG, .patientComplaints, .examinationDescription:
            true
        }
    }

    var canFocusNextField: Bool {
        switch focus {
        case .examinationNumber, .patientName, .patientHeightCM, .patientWeightKG, .patientComplaints:
            true
        case .examinationDescription, .none:
            false
        }
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

    func onSubmit() {
        analytics.buttonTapped(.scanSubmit)
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

    func onTapSettings() {
        analytics.buttonTapped(.scanSettings)
        coordinator.screen(.settings)
    }

    func onTapUSExaminationType() {
        analytics.buttonTapped(.scanUSExaminationType)
        coordinator.sheet(
            .selectUSExaminationType,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: usExaminationType,
                onSelected: { [weak self] usExaminationType in
                    guard let self = self else { return }
                    guard self.usExaminationType != usExaminationType else { return }

                    self.usExaminationType = usExaminationType
                    self.container.ultrasoundReportRepository.setSelectedExaminationTypeId(
                        id: usExaminationType.id
                    )
                }
            )
        )
    }

    var isMediaSelectionDisabled: Bool {
        isPhotoFilling || isLoading
    }

    func onTapCamera() {
        guard !isMediaSelectionDisabled else { return }

        analytics.buttonTapped(.scanCamera)
        unfocus()
        handle {
            await self.container.permissionManager.isGranted(.camera)
        } onMainSuccess: { isGranted in
            guard isGranted else {
                return self.coordinator.sheet(.permissionCamera)
            }

            self.coordinator.sheet(
                .scanCamera,
                arguments: ScanCameraArguments(
                    photos: Binding(
                        get: { [weak self] in
                            self?.photos ?? []
                        },
                        set: { [weak self] photos in
                            self?.photos = photos
                        }
                    ),
                    photoMaxCount: self.photoMaxCount
                )
            )
        }
    }

    func onTapGallery() {
        guard !isMediaSelectionDisabled else { return }

        analytics.buttonTapped(
            .scanGallery,
            parameters: AnalyticsParameters([
                .selectionLimit: .int(gallerySelectionLimit),
            ])
        )
        handle {
            await self.container.permissionManager.isGranted(.photoLibrary)
        } onMainSuccess: { isGranted in
            guard isGranted else {
                return self.coordinator.sheet(.permissionPhotoLibrary)
            }

            self.coordinator.sheet(
                .photoLibraryPicker,
                arguments: PhotoLibraryPickerArguments(
                    selectionLimit: self.gallerySelectionLimit,
                    onComplete: { [weak self] images in
                        guard let self = self else { return }

                        self.onSelectGalleryImages(images)
                    }
                )
            )
        }
    }

    private var gallerySelectionLimit: Int {
        max(photoMaxCount - photos.count, 0)
    }

    private func onSelectGalleryImages(
        _ images: [UIImage]
    ) {
        guard !isPhotoFilling else { return }

        let availableCount = photoMaxCount - photos.count
        Task {
            var newPhotos: [USExaminationScanPhoto] = []
            for image in images.prefix(availableCount) {
                newPhotos.append(await USExaminationScanPhoto.make(image: image))
            }

            withAnimation {
                self.photos.append(contentsOf: newPhotos)
            }
        }
    }

    func onTapDeletePhoto(
        photo: USExaminationScanPhoto
    ) {
        guard let index = photos.firstIndex(of: photo) else { return }

        analytics.buttonTapped(
            .scanDeletePhoto,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        withAnimation {
            _ = photos.remove(at: index)
        }
    }

    func onTapPatientGender(
        value: PatientGender
    ) {
        analytics.buttonTapped(.scanPatientGender)
        guard patientGender != value else { return }

        patientGender = value
    }

    func onTapPatientDateOfBirth() {
        analytics.buttonTapped(.scanPatientDateOfBirth)
        coordinator.sheet(
            .selectDateOfBirth,
            arguments: SelectDateOfBirthArguments(
                currentValue: patientDateOfBirth,
                onSelected: { [weak self] date in
                    guard let self = self else { return }
                    guard self.patientDateOfBirth != date else { return }

                    self.patientDateOfBirth = date
                }
            )
        )
    }

    func onTapSelectedTemplate() {
        analytics.buttonTapped(
            .scanSelectedTemplate,
            parameters: AnalyticsParameters([
                .hasCurrentValue: .bool(getSelectedTemplate() != nil),
            ])
        )
        let usExaminationId = usExaminationType.id
        handle {
            let templates = await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById
            )
            return templates.contains { $0.usExaminationType.id == usExaminationId }
        } onMainSuccess: { hasTemplates in
            guard hasTemplates else {
                return self.coordinator.screen(
                    .templateAdd,
                    arguments: TemplateAddScreenArguments(
                        onAddSuccess: { [weak self] template in
                            self?.onTemplateSelected(template)
                        }
                    )
                )
            }

            self.coordinator.sheet(
                .selectTemplate,
                arguments: SelectTemplateArguments(
                    usExaminationId: usExaminationId,
                    currentValue: self.getSelectedTemplate(),
                    onSelected: { [weak self] template in
                        self?.onTemplateSelected(template)
                    }
                )
            )
        }
    }

    var isSelectedTemplateExaminationTypeMismatch: Bool {
        guard let template = getSelectedTemplate() else { return false }
        return template.usExaminationType.id != usExaminationType.id
    }

    func onTapResetTemplate() {
        analytics.buttonTapped(.scanResetTemplate)
        onTemplateReset()
    }

    func onTapNeuralModelSelection() {
        analytics.buttonTapped(
            .scanNeuralModelSelection,
            parameters: AnalyticsParameters([
                .modelId: .string(getNeuralModel().id),
            ])
        )
        coordinator.sheet(
            .selectNeuralModel,
            arguments: SelectNeuralModelArguments(
                currentValue: getNeuralModel(),
                onSelected: { [weak self] model in
                    self?.onNeuralModelSelected(model)
                }
            )
        )
    }

    func onTapNeuralModelSettings() {
        analytics.buttonTapped(.scanNeuralModelSettings)
        coordinator.run(.neuralModelSettings) {
            self.coordinator.screen(.neuralModelSettings)
        }
    }

    func onTapFill() {
        analytics.buttonTapped(.scanFill)
        patientComplaintsController.setText(
            container.mockFactory.fillPatientComplaints(
                for: Locale.current
            )
        )
        examinationDescriptionController.setText(
            container.mockFactory.fillExaminationDescription(
                for: Locale.current
            )
        )
    }

    var isSpeechButtonVisible: Bool {
        guard container.isUSExaminationNeuralModelAvailable else { return false }

        switch subscription.availability(of: .formCompletionViaMicrophone) {
        case .offered, .available:
            return true
        case .unavailable:
            return false
        }
    }

    var speechButtonBadge: DButtonBadge? {
        switch subscription.availability(of: .formCompletionViaMicrophone) {
        case .offered:
            DButtonBadge(
                .entitlementPro,
                isShimmering: true
            )
        case .available, .unavailable:
            nil
        }
    }

    func onTapSpeech() {
        analytics.buttonTapped(.scanSpeech)
        coordinator.run(.formCompletionViaMicrophone) {
            self.startSpeechFlow()
        }
    }

    private func startSpeechFlow() {
        handle {
            await self.container.permissionManager.isGranted(.speech)
        } onMainSuccess: { isGranted in
            if !isGranted {
                return self.coordinator.sheet(.permissionSpeech)
            }

            self.coordinator.sheet(
                .scanSpeech,
                arguments: ScanSpeechBottomSheetArguments(
                    onComplete: { [weak self] response in
                        guard let self = self else { return }

                        if let patientName = response.patientName {
                            self.patientNameController.setText(patientName)
                        }
                        if let patientGender = PatientGender.fromUSExaminationNeuralModelResponse(response.patientGender) {
                            self.patientGender = patientGender
                        }
                        if let patientDateOfBirth = response.patientDateOfBirth {
                            self.patientDateOfBirth = patientDateOfBirth
                        }
                        if let patientHeightCM = response.patientHeightCM {
                            self.patientHeightCMController.setText("\(patientHeightCM)")
                        }
                        if let patientWeightKG = response.patientWeightKG {
                            self.patientWeightKGController.setText("\(patientWeightKG)")
                        }
                        if let patientComplaints = response.patientComplaints {
                            self.patientComplaintsController.setText(patientComplaints)
                        }
                        if let examinationDescription = response.examinationDescription {
                            self.examinationDescriptionController.setText(examinationDescription)
                        }
                    }
                )
            )
        }
    }

    func onTapScan() {
        analytics.buttonTapped(
            .scanGenerate,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
                .modelId: .string(getNeuralModel().id),
            ])
        )
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        unfocus()

        handle {
            try await self.coordinator.prepareReportGeneration()
        } onMainSuccess: { resolution in
            switch resolution {
            case .proceed:
                self.performScan()
            case .routed:
                break
            }
        }
    }

    private func performScan() {
        guard let examinationNumber = examinationNumberController.value,
              let patientName = patientNameController.value,
              let patientHeightValue = patientHeightCMController.value,
              let patientHeight = Double(patientHeightValue),
              let patientWeightValue = patientWeightKGController.value,
              let patientWeight = Double(patientWeightValue),
              let examinationDescription = examinationDescriptionController.value
        else {
            return
        }

        handle {
            self.isLoading = true

            let neuralModelSettings = self.subscription.neuralModelSettings
            let patientComplaints = self.patientComplaintsController.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let examinationData = USExaminationData(
                usExaminationTypeId: self.usExaminationType.id,
                photos: self.photos,
                examinationNumber: examinationNumber,
                patientName: patientName,
                patientGender: self.patientGender,
                patientDateOfBirth: self.patientDateOfBirth,
                patientHeight: patientHeight,
                patientWeight: patientWeight,
                patientComplaints: patientComplaints?.isEmpty == false ? patientComplaints : nil,
                examinationDescription: examinationDescription
            )
            let template = self.getSelectedTemplate()
            let request = USExaminationRequest(
                neuralModelSettings: neuralModelSettings,
                examinationData: examinationData,
                template: template?.content,
                includeRecommendations: self.container.userSettingsRepository.getIncludeRecommendations()
            )
            let modelReport = try await self.container.ultrasoundReportRepository.generateReport(
                locale: Locale.current,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: self.ultrasoundConfig.scanPhotoResizeMaxDimension,
                    compressionQuality: self.ultrasoundConfig.scanPhotoCompressionQuality
                )
            )
            let report = USExaminationReport(
                date: Date(),
                neuralModelSettings: neuralModelSettings,
                examinationData: examinationData,
                actualModelReport: modelReport,
                previousModelReports: []
            )
            await self.container.ultrasoundReportRepository.setReport(
                report: report
            )
            self.subscription.incrementRequestCount()
            await self.reset()

            return report
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { report in
            self.coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedBottomSheetArguments(
                    report: report
                )
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }

    private func reset() async {
        photos.removeAll()
        let reportsCount = await container.ultrasoundReportRepository.getReportsCount()
        examinationNumberController.setText(
            String(localized: .scanExaminationDefaultNumberLabel(count: reportsCount))
        )
        patientNameController.setText(
            String(localized: .scanPatientDefaultNameLabel(count: reportsCount))
        )
        patientGender = .male
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMController.setText(String(defaultPatientHeightCM))
        patientWeightKGController.setText(String(defaultPatientWeightKG))
        patientComplaintsController.clear()
        examinationDescriptionController.clear()
    }
}
