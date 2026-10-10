import Foundation

struct USExaminationNeuralModel: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let entitlement: SubscriptionType
    let accessibility: USExaminationNeuralModelAccessibility
    let contextLength: Int
    let description: String

    var localizedDescription: LocalizedStringResource {
        LocalizedStringResource(
            stringLiteral: description,
        )
    }
}
