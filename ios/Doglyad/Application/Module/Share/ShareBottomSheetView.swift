import DoglyadUI
import SwiftUI

struct ShareBottomSheetView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @StateObject var viewModel: ShareViewModel

    var body: some View {
        let fraction: CGFloat = switch (viewModel.userEmail, viewModel.subscriptionAvailability(
            of: .sendingReportByEmail,
        )) {
        case (.some, .available), (.some, .offered): 0.4
        default: 0.3
        }

        DBottomSheet(
            title: l10n[
                .shareTitle,
            ],
            fraction: fraction,
        ) { toolbarHeight, _ in
            ShareActionsView(
                toolbarHeight: toolbarHeight,
            )
        }.environmentObject(
            viewModel,
        ).onAppear(
            perform: viewModel.onAppear,
        )
    }
}
