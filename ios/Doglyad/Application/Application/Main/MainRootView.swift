import DoglyadUI
import Router
import StoreKit
import SwiftUI

struct MainRootView: View {
    @Environment(
        \.requestReview,
    ) private var requestReview

    let dependencyContainer: DependencyContainer

    @StateObject private var viewModel: MainRootViewModel
    @StateObject private var ultrasoundViewModel: UltrasoundRootViewModel
    @StateObject private var subscriptionViewModel: SubscriptionRootViewModel

    init(
        dependencyContainer: DependencyContainer,
    ) {
        self.dependencyContainer = dependencyContainer
        _viewModel = StateObject(
            wrappedValue: MainRootViewModel(
                container: dependencyContainer,
            ),
        )
        let ultrasoundViewModel = UltrasoundRootViewModel(
            container: dependencyContainer,
        )
        _ultrasoundViewModel = StateObject(
            wrappedValue: ultrasoundViewModel,
        )
        _subscriptionViewModel = StateObject(
            wrappedValue: SubscriptionRootViewModel(
                container: dependencyContainer,
                getStoredNeuralModelSettings: { [ultrasoundViewModel] in ultrasoundViewModel.storedNeuralModelSettings },
            ),
        )
    }

    var body: some View {
        RouterView<ScreenType, SheetType, FullScreenCoverType, RouterBuilder>(
            builder: RouterBuilder(),
            initialRouteScreen: dependencyContainer.initialRoute,
        )
        .dMessage()
        .environmentObject(
            dependencyContainer,
        )
        .localization(
            dependencyContainer.l10n,
        )
        .environmentObject(
            ultrasoundViewModel,
        )
        .environmentObject(
            subscriptionViewModel,
        )
        .onAppear {
            ultrasoundViewModel.onAppear()
            viewModel.onAppear(
                requestReview: { requestReview() },
            )
        }
    }
}
