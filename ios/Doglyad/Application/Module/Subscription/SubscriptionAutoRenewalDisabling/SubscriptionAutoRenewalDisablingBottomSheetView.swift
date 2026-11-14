import DoglyadUI
import SwiftUI

struct SubscriptionAutoRenewalDisablingBottomSheetView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: SubscriptionAutoRenewalDisablingViewModel

    init(
        viewModel: @autoclosure @escaping () -> SubscriptionAutoRenewalDisablingViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DInfoBottomSheet(
            fraction: 0.6,
            title: l10n[
                .subscriptionAutoRenewalDisablingTitle,
            ],
            image: .doglyadQuestion,
            description: l10n[
                .subscriptionAutoRenewalDisablingDescription,
            ],
            buttonTitle: l10n[
                .subscriptionAutoRenewalDisablingConfirmButton,
            ],
            action: viewModel.onTapConfirm,
            isLoading: viewModel.isProcessing,
            accessibilityIdentifier: "subscriptionAutoRenewalDisabling.confirmation",
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
