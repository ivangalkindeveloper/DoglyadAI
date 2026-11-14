import DoglyadUI
import SwiftUI

struct PaywallPlanCardView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: PaywallViewModel
    let state: PaywallContentState
    let plan: SubscriptionPlan

    init(
        state: PaywallContentState,
        plan: SubscriptionPlan,
    ) {
        self.state = state
        self.plan = plan
    }

    var body: some View {
        let isSelected = state.selectedPlanID == plan.id

        DTextButton(
            action: {
                viewModel.onTapPlan(
                    plan,
                )
            },
            content: {
                HStack(
                    spacing: size.s8,
                ) {
                    DCheck(
                        isChecked: isSelected,
                    )

                    VStack(
                        alignment: .leading,
                        spacing: size.s2,
                    ) {
                        DText(
                            plan.title,
                        )
                        .dStyle(
                            font: typography.linkSmall,
                        )

                        DText(
                            plan.price,
                        )
                        .dStyle(
                            font: typography.textXSmall,
                            color: color.grayscaleLabel,
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading,
                    )
                }
                .padding(
                    size.s8,
                )
                .background(
                    DCardBackground(
                        cornerRadius: size.s64,
                        color: color.grayscaleBackground,
                        borderColor: isSelected ? color.primaryDefault : .clear,
                        lineWidth: size.s1,
                    ),
                )
            },
            isDisabled:
            viewModel.isProcessing,
            accessibilityIdentifier: "paywall.plan.\(plan.id)",
            accessibilityTraits: isSelected ? .isSelected : [],
        )
    }
}
