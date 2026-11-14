import DoglyadUI
import SwiftUI

struct PaywallLoadingErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallCatalogErrorState

    init(
        state: PaywallCatalogErrorState,
    ) {
        self.state = state
    }

    var body: some View {
        ErrorBodyView(
            description: state.errorDescription,
        )
    }
}
