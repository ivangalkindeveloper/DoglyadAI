import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class UltrasoundViewModel: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    private let container: DependencyContainer

    init(
        container: DependencyContainer
    ) {
        self.container = container

        let ultrasoundModelRepository = container.ultrasoundModelRepository
        if let id = ultrasoundModelRepository.getSelectedModelId(),
           let model = container.usExaminationNeuralModelsById[id]
        {
            neuralModel = model
        } else {
            neuralModel = container.usExaminationNeuralModelDefault
        }

        isMarkdown = ultrasoundModelRepository.getIsMarkdown()

        let ultrasoundConfig = container.applicationConfig.ultrasound
        if let temperature = ultrasoundModelRepository.getTemperature() {
            self.temperature = temperature
        } else {
            temperature = ultrasoundConfig.neuralModel.temperature
        }
        if let maxTokens = ultrasoundModelRepository.getMaxTokens() {
            self.maxTokens = maxTokens
        } else {
            maxTokens = ultrasoundConfig.neuralModel.maxTokens
        }

        template = nil
        userEmail = container.userSettingsRepository.getUserEmail()
        includeRecommendations = container.userSettingsRepository.getIncludeRecommendations()
        super.init()
    }

    func onAppear() {
        let templateRepository = container.templateRepository
        guard let selectedTemplateId = templateRepository.getSelectedTemplateId() else {
            template = nil
            return
        }

        handle {
            await templateRepository.getTemplate(
                id: selectedTemplateId,
                usExaminationTypesById: self.container.usExaminationTypesById
            )
        } onMainSuccess: { template in
            guard templateRepository.getSelectedTemplateId() == selectedTemplateId else { return }
            guard let template else {
                templateRepository.clearSelectedTemplateId()
                self.template = nil
                return
            }
            self.template = template
        }
    }

    @Published var neuralModel: USExaminationNeuralModel
    @Published var isMarkdown: Bool
    @Published var temperature: Double
    @Published var maxTokens: Int
    @Published var template: USExaminationTemplate?
    @Published var userEmail: String?
    @Published var includeRecommendations: Bool

    func saveUserSettings(
        userEmail: String?,
        includeRecommendations: Bool
    ) {
        self.userEmail = userEmail
        self.includeRecommendations = includeRecommendations
        container.userSettingsRepository.setUserEmail(userEmail)
        container.userSettingsRepository.setIncludeRecommendations(includeRecommendations)
    }

    func saveNeuralModel(
        _ model: USExaminationNeuralModel
    ) {
        neuralModel = model
        container.ultrasoundModelRepository.setSelectedModelId(id: model.id)
    }

    func selectTemplate(
        _ template: USExaminationTemplate
    ) {
        self.template = template
        container.templateRepository.setSelectedTemplateId(id: template.id)
    }

    func resetTemplate() {
        template = nil
        container.templateRepository.clearSelectedTemplateId()
    }

    func saveNeuralModelSettings(
        isMarkdown: Bool,
        temperature: Double?,
        maxTokens: Int?
    ) {
        self.isMarkdown = isMarkdown
        container.ultrasoundModelRepository.setIsMarkdown(isMarkdown)

        if let temperature = temperature {
            self.temperature = temperature
            container.ultrasoundModelRepository.setTemperature(temperature)
        }

        if let maxTokens = maxTokens {
            self.maxTokens = maxTokens
            container.ultrasoundModelRepository.setMaxTokens(maxTokens)
        }
    }

    func saveTemplate(
        _ template: USExaminationTemplate,
        onChanged: @escaping () -> Void = {}
    ) {
        Task { @MainActor in
            await container.templateRepository.saveTemplate(
                template: template
            )
            if self.template?.id == template.id {
                self.template = template
            }
            onChanged()
        }
    }

    func deleteTemplate(
        id: UUID,
        onChanged: @escaping () -> Void = {}
    ) {
        Task { @MainActor in
            await container.templateRepository.deleteTemplate(id: id)
            if template?.id == id || container.templateRepository.getSelectedTemplateId() == id {
                template = nil
                container.templateRepository.clearSelectedTemplateId()
            }
            onChanged()
        }
    }
}
