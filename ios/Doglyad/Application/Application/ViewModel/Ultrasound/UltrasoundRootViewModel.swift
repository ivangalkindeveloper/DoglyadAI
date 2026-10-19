import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class UltrasoundRootViewModel: DStateViewModel<any UltrasoundRootStateProtocol> {
    @Published var neuralModel: USExaminationNeuralModel
    @Published var isMarkdown: Bool
    @Published var temperature: Double
    @Published var maxTokens: Int
    @Published var transcriberType: TranscriberType
    @Published var transcriptParserType: TranscriptParserType
    @Published var template: USExaminationTemplate?
    @Published var userEmail: String?
    @Published var isRecommendationsIncluded: Bool
    @Published var isPhotoRemarks: Bool
    @Published var isDescriptionRemarks: Bool

    private let container: DependencyContainer
    private let changes = PassthroughSubject<Void, Never>()

    init(
        container: DependencyContainer,
    ) {
        self.container = container

        let settings = container.initialSettingsAI
        neuralModel = settings.selectedNeuralModelId.flatMap { container.usExaminationNeuralModelsById[
            $0,
        ] }
            ?? container.usExaminationNeuralModelDefault
        isMarkdown = settings.isMarkdown
        temperature = settings.temperature ?? container.applicationConfig.ultrasound.neuralModel.temperature
        maxTokens = settings.maxTokens ?? container.applicationConfig.ultrasound.neuralModel.maxTokens
        transcriberType = settings.transcriberType
        transcriptParserType = settings.transcriptParserType
        template = nil
        let userSettings = container.initialUserSettings
        userEmail = userSettings.email
        isRecommendationsIncluded = userSettings.isRecommendationsIncluded
        isPhotoRemarks = userSettings.isPhotoRemarks
        isDescriptionRemarks = userSettings.isDescriptionRemarks

        super.init(
            state: UltrasoundRootState(),
        )
    }

    var storedSettingsAI: SettingsAI {
        SettingsAI(
            transcriberType: transcriberType,
            transcriptParserType: transcriptParserType,
            selectedNeuralModelId: neuralModel.id,
            isMarkdown: isMarkdown,
            temperature: temperature,
            maxTokens: maxTokens,
        )
    }

    func observeChanges(
        _ observer: @escaping () -> Void,
    ) -> AnyCancellable {
        changes.sink { _ in observer() }
    }

    func onAppear() {
        handle {
            let repository = self.container.templateRepository
            guard let id = try await repository.getSelectedTemplateId() else { return nil as USExaminationTemplate? }
            let template = try await repository.getTemplate(
                id: id,
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
            guard try await repository.getSelectedTemplateId() == id else { return self.template }
            if template == nil { try await repository.clearSelectedTemplateId() }
            return template
        } onMainSuccess: { template in self.template = template
            self.changes.send()
        }
    }

    func saveUserSettings(
        userEmail: String?,
        isRecommendationsIncluded: Bool,
        isPhotoRemarks: Bool,
        isDescriptionRemarks: Bool,
    ) async throws {
        let repository = container.userSettingsRepository
        try await repository.setUserEmail(
            userEmail,
        )
        try await repository.setIsRecommendationsIncluded(
            isRecommendationsIncluded,
        )
        try await repository.setIsPhotoRemarks(
            isPhotoRemarks,
        )
        try await repository.setIsDescriptionRemarks(
            isDescriptionRemarks,
        )
        self.userEmail = userEmail
        self.isRecommendationsIncluded = isRecommendationsIncluded
        self.isPhotoRemarks = isPhotoRemarks
        self.isDescriptionRemarks = isDescriptionRemarks
        changes.send()
    }

    func saveNeuralModel(
        _ model: USExaminationNeuralModel,
    ) async throws {
        try await container.settingsAIRepository.saveSettings(
            SettingsAI(
                transcriberType: transcriberType,
                transcriptParserType: transcriptParserType,
                selectedNeuralModelId: model.id,
                isMarkdown: isMarkdown,
                temperature: temperature,
                maxTokens: maxTokens,
            ),
        )
        neuralModel = model
        changes.send()
    }

    func selectTemplate(
        _ template: USExaminationTemplate,
    ) async throws {
        try await container.templateRepository.setSelectedTemplateId(
            id: template.id,
        )
        self.template = template
        changes.send()
    }

    func resetTemplate() async throws {
        try await container.templateRepository.clearSelectedTemplateId()
        template = nil
        changes.send()
    }

    func saveSettingsAI(
        transcriberType: TranscriberType,
        transcriptParserType: TranscriptParserType,
        isMarkdown: Bool,
        temperature: Double?,
        maxTokens: Int?,
    ) async throws {
        let settings = SettingsAI(
            transcriberType: transcriberType,
            transcriptParserType: transcriptParserType,
            selectedNeuralModelId: neuralModel.id,
            isMarkdown: isMarkdown,
            temperature: temperature ?? self.temperature,
            maxTokens: maxTokens ?? self.maxTokens,
        )
        try await container.settingsAIRepository.saveSettings(
            settings,
        )
        self.isMarkdown = settings.isMarkdown
        self.temperature = settings.temperature ?? self.temperature
        self.maxTokens = settings.maxTokens ?? self.maxTokens
        self.transcriberType = settings.transcriberType
        self.transcriptParserType = settings.transcriptParserType
        changes.send()
    }

    func saveTemplate(
        _ template: USExaminationTemplate,
        onChanged: @escaping () -> Void = {},
    ) async throws {
        try await container.templateRepository.saveTemplate(
            template: template,
        )
        if self.template?.id == template.id { self.template = template }
        changes.send()
        onChanged()
    }

    func deleteTemplate(
        id: UUID,
        onChanged: @escaping () -> Void = {},
    ) async throws {
        try await container.templateRepository.deleteTemplate(
            id: id,
        )
        let selectedId = try await container.templateRepository.getSelectedTemplateId()
        if template?.id == id || selectedId == id {
            try await container.templateRepository.clearSelectedTemplateId()
            template = nil
        }
        changes.send()
        onChanged()
    }
}
