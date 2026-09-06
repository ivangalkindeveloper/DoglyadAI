import BottomSheet
import DoglyadCamera
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class ScanViewModel: DViewModel {
    enum Focus: Hashable {
        case patientName
        case patientHeightCM
        case patientWeightKG
        case patientComplaint
        case examinationDescription
    }

    private let messager: DMessager
    private let getTemplateForType: (String) -> USExaminationTemplate?
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        getTemplateForType: @escaping (String) -> USExaminationTemplate?,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.messager = messager
        self.getTemplateForType = getTemplateForType
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
    @NestedObservableObject var cameraController: DCameraControllerFactory.Controller = DCameraControllerFactory.make()
    @NestedObservableObject var sheetController = ScanSheetController()
    //
    @Published var focus: Focus? = nil
    @NestedObservableObject var patientNameController = DTextFieldController(isRequired: true)
    @Published var patientGender = PatientGender.male
    @Published var patientDateOfBirth: Date = .init()
    @NestedObservableObject var patientHeightCMController = DTextFieldController(isRequired: true)
    @NestedObservableObject var patientWeightKGController = DTextFieldController(isRequired: true)
    @NestedObservableObject var patientComplaintController = DTextFieldController(isRequired: true)
    @NestedObservableObject var examinationDescriptionController = DTextFieldController(isRequired: true)
    //
    @Published var isLoading = false

    override func onInit() {
        cameraController.startSession()
        if let usExaminationTypeId = container.ultrasoundConclusionRepository.getSelectedExaminationTypeId(),
           let usExaminationType = container.usExaminationTypesById[usExaminationTypeId]
        {
            self.usExaminationType = usExaminationType
        }
        handle {
            await self.container.ultrasoundConclusionRepository.getConclusionsCount()
        } onMainSuccess: { patientCount in
            self.patientNameController.text = String(localized: .scanPatientDefaultNameLabel(count: patientCount))
        }
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMController.text = String(defaultPatientHeightCM)
        patientWeightKGController.text = String(defaultPatientWeightKG)
    }

    var isPhotoFilling: Bool {
        photos.count == photoMaxCount
    }

    var isCaptureAvailable: Bool {
        cameraController.isRunning && !isPhotoFilling
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(.scanSubmit)
        switch focus {
        case .patientName:
            focus = .patientHeightCM
        case .patientHeightCM:
            focus = .patientWeightKG
        case .patientWeightKG:
            focus = .patientComplaint
        case .patientComplaint:
            focus = .examinationDescription
        case .examinationDescription, .none:
            focus = nil
        }
    }

    func onDisappear() {
        cameraController.stopSession()
    }

    func onChangeContentForSheet() {
        if photos.isEmpty,
           patientComplaintController.text.isEmpty,
           examinationDescriptionController.text.isEmpty
        {
            if focus == nil {
                sheetController.setHidden()
            }
            return
        }
        if sheetController.isHidden {
            sheetController.setBottom()
        }
    }

    func onChangeSheetForCamera() {
        if sheetController.isTop {
            cameraController.stopSession()
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
                    self.container.ultrasoundConclusionRepository.setSelectedExaminationTypeId(
                        id: usExaminationType.id
                    )
                }
            )
        )
    }

    var captureIcon: ImageResource {
        photos.count == photoMaxCount ? .down : .camera
    }

    func onTapCameraTurnOn() {
        analytics.buttonTapped(.scanCameraTurnOn)
        cameraController.startSession()
    }

    func onTapCapture() {
        analytics.buttonTapped(
            .scanCapture,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        if photos.count == photoMaxCount {
            return sheetController.setTop()
        }

        cameraController.takePhoto(
            completion: { [weak self] image in
                guard let self = self else { return }

                self.onCapture(image)
            }
        )
    }

    private func onCapture(
        _ image: UIImage
    ) {
        guard !isPhotoFilling else { return }

        // The thumbnail is prepared off the main thread, otherwise the full-size
        // frame gets decoded on the first PhotoCard render.
        Task {
            let photo = await USExaminationScanPhoto.make(image: image)
            guard !self.isPhotoFilling else { return }

            self.photos.append(photo)
            if self.isPhotoFilling {
                self.sheetController.setTop()
            }
        }
    }

    func onTapGallery() {
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

            self.photos.append(contentsOf: newPhotos)
            if self.isPhotoFilling {
                self.sheetController.setTop()
            }
        }
    }

    func onTapDeletePhoto(
        photo: USExaminationScanPhoto
    ) {
        analytics.buttonTapped(
            .scanDeletePhoto,
            parameters: AnalyticsParameters([
                .itemCount: .int(photos.count),
            ])
        )
        photos.remove(at: photos.firstIndex(of: photo)!)
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

    func getTemplate() -> USExaminationTemplate? {
        getTemplateForType(usExaminationType.id)
    }

    func onTapSelectedTemplate() {
        analytics.buttonTapped(
            .scanSelectedTemplate,
            parameters: AnalyticsParameters([
                .hasCurrentValue: .bool(getTemplate() != nil),
            ])
        )
        if let template = getTemplate() {
            return coordinator.screen(
                .templateEdit,
                arguments: TemplateEditScreenArguments(
                    templateId: template.id
                )
            )
        }

        coordinator.screen(.templateList)
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
        patientComplaintController.text = container.mockFactory.fillPatientComplaint(
            for: Locale.current
        )
        examinationDescriptionController.text = container.mockFactory.fillExaminationDescription(
            for: Locale.current
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

            self.cameraController.stopSession()
            self.coordinator.sheet(
                .scanSpeech,
                arguments: ScanSpeechBottomSheetArguments(
                    onComplete: { [weak self] response in
                        guard let self = self else { return }

                        if let patientName = response.patientName {
                            self.patientNameController.text = patientName
                        }
                        if let patientGender = PatientGender.fromUSExaminationNeuralModelResponse(response.patientGender) {
                            self.patientGender = patientGender
                        }
                        if let patientDateOfBirth = response.patientDateOfBirth {
                            self.patientDateOfBirth = patientDateOfBirth
                        }
                        if let patientHeightCM = response.patientHeightCM {
                            self.patientHeightCMController.text = "\(patientHeightCM)"
                        }
                        if let patientWeightKG = response.patientWeightKG {
                            self.patientWeightKGController.text = "\(patientWeightKG)"
                        }
                        if let patientComplaint = response.patientComplaint {
                            self.patientComplaintController.text = patientComplaint
                        }
                        if let examinationDescription = response.examinationDescription {
                            self.examinationDescriptionController.text = examinationDescription
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
        let isPatientNameValid = patientNameController.validate()
        let isPatientHeightCMValid = patientHeightCMController.validate()
        let isPatientWeightKGValid = patientWeightKGController.validate()
        let isPatientComplaintValid = patientComplaintController.validate()
        let isExaminationDescriptionValid = examinationDescriptionController.validate()
        guard !photos.isEmpty else {
            return messager.show(
                type: .error,
                title: .errorNoScanPhotoTitle,
                description: .errorNoScanPhotoDescription
            )
        }
        guard isPatientNameValid,
              isPatientHeightCMValid,
              isPatientWeightKGValid,
              isPatientComplaintValid,
              isExaminationDescriptionValid
        else {
            return
        }

        unfocus()

        handle {
            try await self.coordinator.prepareConclusionGeneration()
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
        handle {
            self.isLoading = true

            let neuralModelSettings = self.subscription.neuralModelSettings
            let examinationData = USExaminationData(
                usExaminationTypeId: self.usExaminationType.id,
                photos: self.photos,
                patientName: self.patientNameController.text,
                patientGender: self.patientGender,
                patientDateOfBirth: self.patientDateOfBirth,
                patientHeight: Double(self.patientHeightCMController.text) ?? self.defaultPatientHeightCM,
                patientWeight: Double(self.patientWeightKGController.text) ?? self.defaultPatientWeightKG,
                patientComplaint: self.patientComplaintController.text,
                examinationDescription: self.examinationDescriptionController.text
            )
            let template = self.getTemplate()
            let request = USExaminationRequest(
                neuralModelSettings: neuralModelSettings,
                examinationData: examinationData,
                template: template?.content
            )
            let modelConclusion = try await self.container.ultrasoundConclusionRepository.generateConclusion(
                locale: Locale.current,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: self.ultrasoundConfig.scanPhotoResizeMaxDimension,
                    compressionQuality: self.ultrasoundConfig.scanPhotoCompressionQuality
                )
            )
            let conclusion = USExaminationConclusion(
                date: Date(),
                neuralModelSettings: neuralModelSettings,
                examinationData: examinationData,
                actualModelConclusion: modelConclusion,
                previosModelConclusions: []
            )
            await self.container.ultrasoundConclusionRepository.setConclusion(
                conclusion: conclusion
            )
            self.subscription.incrementRequestCount()
            await self.reset()

            return conclusion
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { conclusion in
            self.coordinator.sheet(
                .recievedConclusion,
                arguments: RecievedConclusionBottomSheetArguments(
                    conclusion: conclusion
                )
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }

    private func reset() async {
        sheetController.setHidden()
        photos.removeAll()
        let patientCount = await container.ultrasoundConclusionRepository.getConclusionsCount()
        patientNameController.text = String(localized: .scanPatientDefaultNameLabel(count: patientCount))
        patientGender = .male
        patientDateOfBirth = defaultPatientDateOfBirth
        patientHeightCMController.text = String(defaultPatientHeightCM)
        patientWeightKGController.text = String(defaultPatientWeightKG)
        patientComplaintController.clear()
        examinationDescriptionController.clear()
    }
}
