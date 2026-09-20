import DoglyadUI
import Router
import StoreKit
import SwiftUI

struct MainRootView: View {
    @Environment(\.requestReview) private var requestReview

    let dependencyContainer: DependencyContainer

    @StateObject private var viewModel: MainRootViewModel
    @StateObject private var ultrasoundViewModel: UltrasoundViewModel
    @StateObject private var subscriptionViewModel: SubscriptionViewModel

    init(
        dependencyContainer: DependencyContainer
    ) {
        self.dependencyContainer = dependencyContainer
        _viewModel = StateObject(wrappedValue: MainRootViewModel(
            container: dependencyContainer
        ))
        _ultrasoundViewModel = StateObject(wrappedValue: UltrasoundViewModel(
            container: dependencyContainer
        ))
        _subscriptionViewModel = StateObject(wrappedValue: SubscriptionViewModel(
            container: dependencyContainer
        ))
    }

    var body: some View {
        RouterView<ScreenType, SheetType, FullScreenCoverType, RouterBuilder>(
            builder: RouterBuilder(),
            initialRouteScreen: dependencyContainer.initialRoute
        )
        .dMessage()
        .environmentObject(dependencyContainer)
        .environmentObject(ultrasoundViewModel)
        .environmentObject(subscriptionViewModel)
        .onAppear {
            ultrasoundViewModel.onAppear()
            viewModel.onAppear(requestReview: { requestReview() })
        }
    }
}
