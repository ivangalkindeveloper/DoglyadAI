import DoglyadUI
import SwiftUI

struct RequestLimitExceededBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: RequestLimitExceededViewModel

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.5,
            title: l10n[
                .requestLimitExceededTitle,
            ],
            image: .doglyadAbout,
            description: l10n[
                .requestLimitExceededDescription,
            ],
            buttonTitle: l10n[
                .buttonManageSubscription,
            ],
            action: viewModel.onTapUpgrade,
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
