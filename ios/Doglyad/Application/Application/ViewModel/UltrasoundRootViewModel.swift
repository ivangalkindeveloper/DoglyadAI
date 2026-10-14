import Combine
import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class UltrasoundRootViewModel: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    private let container: DependencyContainer

    init(
        container: DependencyContainer,
    ) {
        self.container = container

        let settings = container.initialNeuralModelSettings
        neuralModel = settings.selectedNeuralModelId.flatMap { container.usExaminationNeuralModelsById[
            $0,
        ] }
            ?? container.usExaminationNeuralModelDefault
        isMarkdown = settings.isMarkdown
        temperature = settings.temperature ?? container.applicationConfig.ultrasound.neuralModel.temperature
        maxTokens = settings.maxTokens ?? container.applicationConfig.ultrasound.neuralModel.maxTokens
        template = nil
        let userSettings = container.initialUserSettings
        userEmail = userSettings.email
        isRecommendationsIncluded = userSettings.isRecommendationsIncluded
        isPhotoRemarks = userSettings.isPhotoRemarks
        isDescriptionRemarks = userSettings.isDescriptionRemarks
        super.init()
    }

    func observeChanges(
        _ observer: @escaping () -> Void,
    ) -> AnyCancellable {
        objectWillChange.sink { _ in observer() }
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
        } onMainSuccess: { template in self.template = template }
    }

    @Published var neuralModel: USExaminationNeuralModel
    @Published var isMarkdown: Bool
    @Published var temperature: Double
    @Published var maxTokens: Int
    @Published var template: USExaminationTemplate?
    @Published var userEmail: String?
    @Published var isRecommendationsIncluded: Bool
    @Published var isPhotoRemarks: Bool
    @Published var isDescriptionRemarks: Bool

    var storedNeuralModelSettings: NeuralModelSettings {
        NeuralModelSettings(
            selectedNeuralModelId: neuralModel.id,
            isMarkdown: isMarkdown,
            temperature: temperature,
            maxTokens: maxTokens,
        )
    }

    func saveUserSettings(
        userEmail: String?,
        isRecommendationsIncluded: Bool,
        isPhotoRemarks: Bool,
        isDescriptionRemarks: Bool,
    ) async throws {
        let repository = container.userSettingsRepository
        try await repository.setIsPhotoRemarks(
            isPhotoRemarks,
        )
        try await repository.setIsDescriptionRemarks(
            isDescriptionRemarks,
        )
        try await repository.setUserEmail(
            userEmail,
        )
        try await repository.setIsRecommendationsIncluded(
            isRecommendationsIncluded,
        )
        self.userEmail = userEmail
        self.isRecommendationsIncluded = isRecommendationsIncluded
        self.isPhotoRemarks = isPhotoRemarks
        self.isDescriptionRemarks = isDescriptionRemarks
    }

    func saveNeuralModel(
        _ model: USExaminationNeuralModel,
    ) async throws {
        try await container.ultrasoundModelRepository.setSelectedModelId(
            id: model.id,
        )
        neuralModel = model
    }

    func selectTemplate(
        _ template: USExaminationTemplate,
    ) async throws {
        try await container.templateRepository.setSelectedTemplateId(
            id: template.id,
        )
        self.template = template
    }

    func resetTemplate() async throws {
        try await container.templateRepository.clearSelectedTemplateId()
        template = nil
    }

    func saveNeuralModelSettings(
        isMarkdown: Bool,
        temperature: Double?,
        maxTokens: Int?,
    ) async throws {
        let repository = container.ultrasoundModelRepository
        try await repository.setIsMarkdown(
            isMarkdown,
        )
        if let temperature { try await repository.setTemperature(
            temperature,
        ) }
        if let maxTokens { try await repository.setMaxTokens(
            maxTokens,
        ) }
        self.isMarkdown = isMarkdown
        if let temperature { self.temperature = temperature }
        if let maxTokens { self.maxTokens = maxTokens }
    }

    func saveTemplate(
        _ template: USExaminationTemplate,
        onChanged: @escaping () -> Void = {},
    ) async throws {
        try await container.templateRepository.saveTemplate(
            template: template,
        )
        if self.template?.id == template.id { self.template = template }
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
        onChanged()
    }
}
