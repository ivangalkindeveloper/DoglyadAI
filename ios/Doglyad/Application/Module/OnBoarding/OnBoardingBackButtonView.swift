import DoglyadUI
import SwiftUI

struct OnBoardingBackButtonView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: OnBoardingViewModel

    var body: some View {
        switch viewModel.state {
        case _ as OnBoardingFirstState, _ as OnBoardingCompletingState: EmptyView()
        default:
            DButton(
                image: .back,
                action: viewModel.onPressedBack,
            )
            .dStyle(
                .circle,
            )
            .accessibilityIdentifier(
                "onboarding.back",
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
