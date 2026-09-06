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
        case .sendingConclusionByEmail:
            sendingConclusionByEmail
        }
    }

    var requestCountPerDay: Int {
        entitlement.requestCountPerDay
    }

    var formCompletionViaMicrophone: SubscriptionFeatureAvailability {
        entitlement.formCompletionViaMicrophone
    }

    var sendingConclusionByEmail: SubscriptionFeatureAvailability {
        entitlement.sendingConclusionByEmail
    }

    var neuralModelSettings: SubscriptionFeatureAvailability {
        entitlement.neuralModelSettings
    }
}
