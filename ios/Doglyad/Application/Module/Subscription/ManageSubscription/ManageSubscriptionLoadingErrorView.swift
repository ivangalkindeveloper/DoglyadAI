import DoglyadUI
import SwiftUI

struct ManageSubscriptionLoadingErrorView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    let state: ManageSubscriptionErrorState

    var body: some View {
        ErrorBodyView(
            description: state.errorDescription,
        )
    }
}
