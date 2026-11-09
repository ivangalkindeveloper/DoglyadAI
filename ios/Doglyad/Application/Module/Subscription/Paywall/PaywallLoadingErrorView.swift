import DoglyadUI
import SwiftUI

struct PaywallLoadingErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: PaywallCatalogErrorState

    var body: some View {
        ErrorBodyView(
            description: state.errorDescription,
        )
    }
}
