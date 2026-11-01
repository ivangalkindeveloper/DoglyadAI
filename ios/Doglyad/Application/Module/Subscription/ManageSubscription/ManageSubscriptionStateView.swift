import DoglyadUI
import SwiftUI

struct ManageSubscriptionStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let state: any ManageSubscriptionStateProtocol

    var body: some View {
        switch state {
        case let loading as ManageSubscriptionLoadingState:
            if let previous = loading.previousState {
                VStack(
                    alignment: .leading,
                    spacing: size.s8,
                ) {
                    DText(
                        l10n[
                            .manageSubscriptionUpdatingDescription,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleLabel,
                    )
                    DShimmerPlaceholder().frame(
                        height: size.s8,
                    )
                }
                ManageSubscriptionContentView(
                    state: previous,
                )
            } else { ManageSubscriptionLoadingView() }
        case let failed as ManageSubscriptionFailedState:
            ManageSubscriptionErrorCardView(
                state: failed,
            )
            if let previous = failed.previousState { ManageSubscriptionContentView(
                state: previous,
            ) }
        case let content as ManageSubscriptionContentState: ManageSubscriptionContentView(
                state: content,
            )
        default: EmptyView()
        }
    }
}
