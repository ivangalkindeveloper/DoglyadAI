import DoglyadUI
import SwiftUI

struct SubscriptionPaywallLoadingErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: SubscriptionPaywallCatalogErrorState

    init(
        state: SubscriptionPaywallCatalogErrorState,
    ) {
        self.state = state
    }

    var body: some View {
        ErrorBodyView(
            description: state.errorDescription,
        )
    }
}
