import DoglyadUI
import SwiftUI

struct OnBoardingBackButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: OnBoardingViewModel

    var body: some View {
        switch viewModel.state {
        case _ as OnBoardingInitialState: EmptyView()
        default:
            DButton(
                image: .back,
                action: viewModel.onPressedBack,
                accessibilityIdentifier: "onboarding.back",
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
