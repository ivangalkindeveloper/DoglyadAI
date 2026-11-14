import DoglyadUI
import SwiftUI

struct ApplicationRootView: View {
    @EnvironmentObject private var viewModel: ApplicationRootViewModel

    init() {}

    var body: some View {
        ZStack {
            Group {
                switch (viewModel.state.id, viewModel.state) {
                case (.splash, _):
                    ApplicationSplashView()
                case let (.error, state as ApplicationRootLoadingState):
                    if let failure = state.previousFailure {
                        ErrorRootView(
                            error: failure.error,
                            analytics: viewModel.analytics,
                        )
                    }
                case let (.main, state as ApplicationRootSuccessState):
                    MainRootView(
                        dependencyContainer: state.container,
                    )
                case let (.error, state as ApplicationRootErrorState):
                    ErrorRootView(
                        error: state.error,
                        analytics: viewModel.analytics,
                    )
                default: EmptyView()
                }
            }
            .id(
                viewModel.state.id,
            )
            .transition(
                .opacity,
            )
        }
    }
}
