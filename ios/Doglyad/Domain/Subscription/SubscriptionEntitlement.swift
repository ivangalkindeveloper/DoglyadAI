import Foundation

struct SubscriptionEntitlement: Codable, Equatable {
    let requestCountPerDay: Int
    let formCompletionViaMicrophone: SubscriptionFeatureAvailability
    let sendingReportByEmail: SubscriptionFeatureAvailability
    let neuralModelSettings: SubscriptionFeatureAvailability
}
