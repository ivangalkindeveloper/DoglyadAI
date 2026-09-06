import DoglyadUI
import Router
import SwiftUI

struct MainRootView: View {
    let dependencyContainer: DependencyContainer

    @StateObject private var ultrasoundViewModel: UltrasoundViewModel
    @StateObject private var subscriptionViewModel: SubscriptionViewModel

    init(
        dependencyContainer: DependencyContainer
    ) {
        self.dependencyContainer = dependencyContainer
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
        }
    }
}
