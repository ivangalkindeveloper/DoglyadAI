import Foundation

struct InitialNavigationContext {
    let applicationConfig: ApplicationConfig
    let isOnBoardingCompleted: Bool
    let selectedUSExaminationTypeId: String?
    let acceptedLegalDocumentDate: Date?
    let conclusionsCount: Int
    let subscriptionStatus: SubscriptionStatus?

    init(
        applicationConfig: ApplicationConfig,
        isOnBoardingCompleted: Bool,
        selectedUSExaminationTypeId: String?,
        acceptedLegalDocumentDate: Date?,
        conclusionsCount: Int,
        subscriptionStatus: SubscriptionStatus?,
    ) {
        self.applicationConfig = applicationConfig
        self.isOnBoardingCompleted = isOnBoardingCompleted
        self.selectedUSExaminationTypeId = selectedUSExaminationTypeId
        self.acceptedLegalDocumentDate = acceptedLegalDocumentDate
        self.conclusionsCount = conclusionsCount
        self.subscriptionStatus = subscriptionStatus
    }
}
