import DoglyadUI
import SwiftUI

struct PaywallPlansView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N

    let state: PaywallContentState

    var body: some View {
        VStack(
            spacing: size.s8,
        ) {
            ForEach(
                state.displayedPlans,
            ) { plan in
                PaywallPlanCardView(
                    state: state,
                    plan: plan,
                )
            }
            if state.displayedPlans.isEmpty {
                DText(
                    l10n[
                        .paywallEmptyPlansDescription,
                    ],
                )
                .dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleLabel,
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
            }
        }
        .padding(
            .bottom,
            size.s8,
        )
    }
}
