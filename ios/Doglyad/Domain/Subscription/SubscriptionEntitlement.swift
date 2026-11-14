import Foundation

struct SubscriptionEntitlement: Codable, Equatable {
    let requestCountPerDay: Int
    let formCompletionViaMicrophone: SubscriptionFeatureAvailability
    let sendingReportByEmail: SubscriptionFeatureAvailability
    let settingsAI: SubscriptionFeatureAvailability

    init(
        requestCountPerDay: Int,
        formCompletionViaMicrophone: SubscriptionFeatureAvailability,
        sendingReportByEmail: SubscriptionFeatureAvailability,
        settingsAI: SubscriptionFeatureAvailability,
    ) {
        self.requestCountPerDay = requestCountPerDay
        self.formCompletionViaMicrophone = formCompletionViaMicrophone
        self.sendingReportByEmail = sendingReportByEmail
        self.settingsAI = settingsAI
    }
}
