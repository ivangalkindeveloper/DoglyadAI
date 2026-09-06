import DoglyadNetwork
import Foundation
import Handler

@MainActor
final class UltrasoundViewModel: Handler<DHttpApiError, DHttpConnectionError>, ObservableObject {
    private var isInitialized = false
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

        templateIdByUSExaminationTypeId = [:]
        userEmail = container.userSettingsRepository.getUserEmail()
        super.init()
    }

    func onAppear() {
        guard !isInitialized else { return }
        isInitialized = true

        handle {
            self.templateIdByUSExaminationTypeId = await self.container.templateRepository
                .getTemplatesByUSExaminationId(
                    usExaminationTypesById: self.container.usExaminationTypesById
                )
        }
    }

    @Published var neuralModel: USExaminationNeuralModel
    @Published var isMarkdown: Bool
    @Published var temperature: Double
    @Published var maxTokens: Int
    @Published var templateIdByUSExaminationTypeId: [String: USExaminationTemplate]
    @Published var userEmail: String?

    func saveUserEmail(
        userEmail: String
    ) {
        self.userEmail = userEmail
        container.userSettingsRepository.setUserEmail(userEmail)
    }

    func saveNeuralModel(
        _ model: USExaminationNeuralModel
    ) {
        neuralModel = model
        container.ultrasoundModelRepository.setSelectedModelId(id: model.id)
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
        _ template: USExaminationTemplate
    ) {
        Task { @MainActor in
            await container.templateRepository.saveTemplate(
                template: template
            )
            templateIdByUSExaminationTypeId = await container.templateRepository
                .getTemplatesByUSExaminationId(
                    usExaminationTypesById: container.usExaminationTypesById
                )
        }
    }

    func deleteTemplate(
        id: UUID
    ) {
        Task { @MainActor in
            await container.templateRepository.deleteTemplate(id: id)
            templateIdByUSExaminationTypeId = await container.templateRepository
                .getTemplatesByUSExaminationId(
                    usExaminationTypesById: container.usExaminationTypesById
                )
        }
    }
}
