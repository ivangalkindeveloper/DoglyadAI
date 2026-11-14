import DoglyadUI
import SwiftUI

struct RequestLimitExceededBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: RequestLimitExceededViewModel

    init(
        viewModel: @autoclosure @escaping () -> RequestLimitExceededViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

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
                .buttonSubscriptionManage,
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
