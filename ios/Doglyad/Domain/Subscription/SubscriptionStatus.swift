import Foundation

struct SubscriptionStatus: Equatable {
    let type: SubscriptionType
    let entitlement: SubscriptionEntitlement
    let availableCountPerDay: Int
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
        of feature: PaidFeature,
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
