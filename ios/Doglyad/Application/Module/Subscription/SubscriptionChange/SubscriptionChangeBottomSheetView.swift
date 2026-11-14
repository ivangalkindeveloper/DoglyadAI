import DoglyadUI
import SwiftUI

struct SubscriptionChangeBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionChangeViewModel

    init(
        viewModel: @autoclosure @escaping () -> SubscriptionChangeViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.6,
            title: l10n[
                .subscriptionChangeTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                viewModel.descriptionKey,
            ],
            buttonTitle: l10n[
                .subscriptionChangeConfirmButton,
            ],
            action: viewModel.onTapConfirm,
            accessibilityIdentifier: "subscriptionChange.confirmation",
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
        .onDisappear(
            perform: viewModel.onDisappear,
        )
    }
}
