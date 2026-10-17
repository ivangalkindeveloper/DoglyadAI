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
                    case .none: DUnexpectedStateView(
                            state: viewModel.state,
                        )
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
                default: DUnexpectedStateView(
                        state: viewModel.state,
                    )
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
