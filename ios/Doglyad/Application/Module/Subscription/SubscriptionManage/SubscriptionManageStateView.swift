import DoglyadUI
import SwiftUI

struct SubscriptionManageStateView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    let state: any SubscriptionManageStateProtocol

    init(
        state: any SubscriptionManageStateProtocol,
    ) {
        self.state = state
    }

    var body: some View {
        switch state {
        case _ as SubscriptionManageLoadingState:
            SubscriptionManageLoadingView()
        case let content as SubscriptionManageSuccessState:
            SubscriptionManageContentView(
                state: content,
            )
        default: EmptyView()
        }
    }
}
