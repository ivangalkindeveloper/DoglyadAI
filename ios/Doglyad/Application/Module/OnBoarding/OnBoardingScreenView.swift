import DoglyadUI
import SwiftUI

struct OnBoardingScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: OnBoardingViewModel

    init(
        viewModel: @autoclosure @escaping () -> OnBoardingViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        let (isDisabled, isProcessing): (Bool, Bool) = switch viewModel.state {
        case let state as OnBoardingLegalState: (!state.isLegalAccepted, false)
        case _ as OnBoardingLoadingState: (false, true)
        default: (false, false)
        }

        DScreen(
            content: { _, bottomHeight in
                VStack(
                    alignment: .leading,
                    spacing: .zero,
                ) {
                    DPageIndicator(
                        count: 5,
                        currentIndex: viewModel.state.index,
                    )
                    .padding(
                        .bottom,
                        size.s16,
                    )

                    OnBoardingCurrentPageView()
                        .id(
                            viewModel.state.index,
                        )
                        .transition(
                            .opacity,
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                        )
                }
                .padding(
                    size.s16,
                )
                .padding(
                    .bottom,
                    bottomHeight,
                )
            },
            bottom: {
                HStack(
                    spacing: size.s8,
                ) {
                    OnBoardingBackButtonView()

                    DButton(
                        title: l10n[
                            viewModel.state.primaryButtonTitleKey,
                        ],
                        action: viewModel.onPressedNext,
                        isLoading: isProcessing,
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "onboarding.primary",
                    )
                    .dStyle(
                        .primaryButton,
                    )
                }
                .padding(
                    size.s16,
                )

            },
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
