@MainActor
class PaywallSuccessState: PaywallContentState {
    override required init(
        tiers: [SubscriptionTier],
        plans: [SubscriptionPlan],
        selectedType: SubscriptionType,
        selectedPlanID: String?,
        isAutoRenewing: Bool = true,
    ) {
        super.init(
            tiers: tiers,
            plans: plans,
            selectedType: selectedType,
            selectedPlanID: selectedPlanID,
            isAutoRenewing: isAutoRenewing,
        )
    }

    override convenience init(
        copying content: PaywallContentState,
    ) {
        self.init(
            tiers: content.tiers,
            plans: content.plans,
            selectedType: content.selectedType,
            selectedPlanID: content.selectedPlanID,
            isAutoRenewing: content.isAutoRenewing,
        )
    }

    func copyWith(
        selectedType: SubscriptionType? = nil,
        selectedPlanID: String? = nil,
        isAutoRenewing: Bool? = nil,
    ) -> Self {
        Self(
            tiers: tiers,
            plans: plans,
            selectedType: selectedType ?? self.selectedType,
            selectedPlanID: selectedPlanID ?? self.selectedPlanID,
            isAutoRenewing: isAutoRenewing ?? self.isAutoRenewing,
        )
    }
}
