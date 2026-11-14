@MainActor
final class PaywallPaymentPendingState: PaywallSuccessState {
    required init(
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
}
