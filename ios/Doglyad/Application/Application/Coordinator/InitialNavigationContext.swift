import Foundation

struct InitialNavigationContext {
    let applicationConfig: ApplicationConfig
    let applicationVersion: Version
    let isOnBoardingCompleted: Bool
    let selectedUSExaminationTypeId: String?
    let acceptedLegalDocumentDate: Date?
    let conclusionsCount: Int
    let subscriptionStatus: SubscriptionStatus?
}
