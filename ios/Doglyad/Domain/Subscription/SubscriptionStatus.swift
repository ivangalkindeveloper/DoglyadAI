import Foundation

struct SubscriptionStatus: Equatable {
    let type: SubscriptionType
    let entitlement: SubscriptionEntitlement
    let availableCountPerDay: Int
}

extension SubscriptionStatus {
    func availability(of feature: PaidFeature) -> SubscriptionFeatureAvailability {
        switch feature {
        case .neuralModelSettings:
            neuralModelSettings
        case .formCompletionViaMicrophone:
            formCompletionViaMicrophone
        case .sendingReportByEmail:
            sendingReportByEmail
        }
    }

    var requestCountPerDay: Int {
        entitlement.requestCountPerDay
    }

    var formCompletionViaMicrophone: SubscriptionFeatureAvailability {
        entitlement.formCompletionViaMicrophone
    }

    var sendingReportByEmail: SubscriptionFeatureAvailability {
        entitlement.sendingReportByEmail
    }

    var neuralModelSettings: SubscriptionFeatureAvailability {
        entitlement.neuralModelSettings
    }
}
