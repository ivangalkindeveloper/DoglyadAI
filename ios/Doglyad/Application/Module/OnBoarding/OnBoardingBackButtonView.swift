import DoglyadUI
import SwiftUI

struct OnBoardingBackButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: OnBoardingViewModel

    var body: some View {
        switch viewModel.state {
        case _ as OnBoardingInitialState, _ as OnBoardingLoadingState: EmptyView()
        default:
            DButton(
                image: .back,
                accessibilityIdentifier: "onboarding.back",
                action: viewModel.onPressedBack,
            )
            .dStyle(
                .circle,
            )

            .transition(
                .scale
                    .combined(
                        with: .opacity,
                    ),
            )
        }
    }
}
