import DoglyadUI
import SwiftUI

struct ManageSubscriptionScrollableView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ManageSubscriptionViewModel
    let state: any ManageSubscriptionStateProtocol
    let toolbarInset: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        DScrollVStack(
            spacing: size.s8,
            padding: EdgeInsets(
                top: toolbarInset + size.s16,
                leading: size.s16,
                bottom: bottomInset + size.s32,
                trailing: size.s16,
            ),
        ) {
            ManageSubscriptionStateView(
                state: state,
            )
        }
    }
}
