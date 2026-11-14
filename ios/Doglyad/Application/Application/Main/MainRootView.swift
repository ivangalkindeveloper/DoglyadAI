import DoglyadUI
import Router
import StoreKit
import SwiftUI

struct MainRootView: View {
    @Environment(
        \.requestReview,
    ) private var requestReview
    @Environment(
        \.scenePhase,
    ) private var scenePhase
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
                getStoredSettingsAI: { [ultrasoundViewModel] in
                    ultrasoundViewModel.storedSettingsAI
                },
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
        .onReceive(
            ultrasoundViewModel.reportGenerations.terminalEvents,
        ) { _ in
            Task {
                await subscriptionViewModel.refreshStatus()
            }
        }
        .onChange(
            of: scenePhase,
        ) { _, phase in
            switch phase {
            case .background:
                ultrasoundViewModel.reportGenerations.setInBackground(
                    true,
                )
            case .active:
                Task {
                    await subscriptionViewModel.refreshStatus()
                }
                ultrasoundViewModel.reportGenerations.setInBackground(
                    false,
                )
            case .inactive: break
            @unknown default: break
            }
        }
        .onAppear {
            subscriptionViewModel.onInit()
            ultrasoundViewModel.onAppear()
            viewModel.onAppear(
                requestReview: {
                    #if !DOGLYAD_REGRESSION
                        requestReview()
                    #endif
                },
            )
        }
    }
}
