import Foundation

/// Immutable catalog and selection shared by the loaded paywall phases.
@MainActor
class PaywallContentState: PaywallStateProtocol, @MainActor Equatable {
    let tiers: [SubscriptionTier]
    let plans: [SubscriptionPlan]
    let selectedType: SubscriptionType
    let selectedPlanID: String?

    init(
        tiers: [SubscriptionTier],
        plans: [SubscriptionPlan],
        selectedType: SubscriptionType,
        selectedPlanID: String?,
    ) {
        self.tiers = tiers
        self.plans = plans
        self.selectedType = selectedType
        self.selectedPlanID = selectedPlanID
    }

    init(
        copying content: PaywallContentState,
    ) {
        tiers = content.tiers
        plans = content.plans
        selectedType = content.selectedType
        selectedPlanID = content.selectedPlanID
    }

    var selectedTier: SubscriptionTier? {
        tiers.first {
            $0.id == selectedType
        }
    }

    var displayedPlans: [SubscriptionPlan] {
        plans.filter {
            $0.type == selectedType
        }
    }

    var selectedPlan: SubscriptionPlan? {
        displayedPlans.first {
            $0.id == selectedPlanID
        }
    }

    func equals(
        _ other: PaywallContentState,
    ) -> Bool {
        type(
            of: self,
        ) == type(
            of: other,
        ) && tiers == other.tiers && plans == other.plans && selectedType == other.selectedType && selectedPlanID == other.selectedPlanID
    }

    static func == (
        lhs: PaywallContentState,
        rhs: PaywallContentState,
    ) -> Bool {
        lhs.equals(
            rhs,
        )
    }
}
