import Foundation

struct SubscriptionStatus: Equatable {
    let planId: String
    let type: SubscriptionType
    let entitlement: SubscriptionEntitlement
    let availableCountPerDay: Int
    var source: SubscriptionSource?
    var expiresAt: Date?
    var isAutoRenewing: Bool = false

    init(
        planId: String,
        type: SubscriptionType,
        entitlement: SubscriptionEntitlement,
        availableCountPerDay: Int,
        source: SubscriptionSource? = nil,
        expiresAt: Date? = nil,
        isAutoRenewing: Bool = false,
    ) {
        self.planId = planId
        self.type = type
        self.entitlement = entitlement
        self.availableCountPerDay = availableCountPerDay
        self.source = source
        self.expiresAt = expiresAt
        self.isAutoRenewing = isAutoRenewing
    }
}

extension SubscriptionStatus {
    var requestCountPerDay: Int {
        entitlement.requestCountPerDay
    }

    var formCompletionViaMicrophone: SubscriptionFeatureAvailability {
        entitlement.formCompletionViaMicrophone
    }

    var sendingReportByEmail: SubscriptionFeatureAvailability {
        entitlement.sendingReportByEmail
    }

    var settingsAI: SubscriptionFeatureAvailability {
        entitlement.settingsAI
    }

    var isReportGenerationSettingsAvailable: Bool {
        switch type {
        case .base:
            false
        case .pro:
            switch settingsAI {
            case .available:
                true
            case .offered, .unavailable:
                false
            }
        }
    }

    func availability(
        of feature: SubscriptionPaidFeature,
    ) -> SubscriptionFeatureAvailability {
        switch feature {
        case .settingsAI:
            settingsAI
        case .formCompletionViaMicrophone:
            formCompletionViaMicrophone
        case .sendingReportByEmail:
            sendingReportByEmail
        }
    }
}
