import DoglyadUI
import SwiftUI

struct OnBoardingScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: OnBoardingViewModel

    var body: some View {
        let isDisabled: Bool = switch viewModel.state {
        case let state as OnBoardingLegalState: !state.isLegalAccepted
        case _ as OnBoardingCompletingState: true
        default: false
        }
        let isProcessing = switch viewModel.state {
        case _ as OnBoardingCompletingState: true
        default: false
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
                        .transition(
                            .scale
                                .combined(
                                    with: .opacity,
                                ),
                        )
                    }

                    DButton(
                        title: l10n[
                            viewModel.state.primaryButtonTitleKey,
                        ],
                        action: viewModel.onPressedNext,
                        isLoading: isProcessing,
                        isDisabled: isDisabled,
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
