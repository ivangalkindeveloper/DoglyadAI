import Foundation

struct USExaminationNeuralModel: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let format: String
    let entitlement: SubscriptionType
    let accessibility: USExaminationNeuralModelAccessibility
    let contextLength: Int
    let description: String

    init(
        id: String,
        title: String,
        format: String,
        entitlement: SubscriptionType,
        accessibility: USExaminationNeuralModelAccessibility,
        contextLength: Int,
        description: String,
    ) {
        self.id = id
        self.title = title
        self.format = format
        self.entitlement = entitlement
        self.accessibility = accessibility
        self.contextLength = contextLength
        self.description = description
    }

    var localizedDescription: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: description,
        )
    }
}
