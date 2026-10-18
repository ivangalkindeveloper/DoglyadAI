import DoglyadUI
import SwiftUI

struct ApplicationRootView: View {
    @EnvironmentObject private var viewModel: ApplicationRootViewModel

    var body: some View {
        ZStack {
            Group {
                switch (viewModel.state.id, viewModel.state) {
                case (.splash, _):
                    ApplicationSplashView()
                case let (.error, state as ApplicationRootInitializingState):
                    switch state.previousFailure {
                    case let .some(
                        failure,
                    ):
                        ErrorRootView(
                            error: failure.error,
                            analytics: viewModel.analytics,
                        )
                    case .none: EmptyView()
                    }
                case let (.main, state as ApplicationRootReadyState):
                    MainRootView(
                        dependencyContainer: state.container,
                    )
                case let (.error, state as ApplicationRootFailedState):
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
