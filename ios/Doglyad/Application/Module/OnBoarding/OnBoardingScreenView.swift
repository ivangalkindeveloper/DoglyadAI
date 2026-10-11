import DoglyadUI
import SwiftUI

struct OnBoardingScreenView: DView {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: OnBoardingViewModel

    var body: some View {
        DScreen(
            content: { _, bottomHeight in
                VStack(
                    alignment: .leading,
                    spacing: .zero,
                ) {
                    stepper
                        .padding(
                            .bottom,
                            size.s16,
                        )

                    currentPage
                        .id(
                            viewModel.page,
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
                .animation(
                    .easeInOut,
                    value: viewModel.page,
                )
            },
            bottom: {
                HStack(
                    spacing: size.s8,
                ) {
                    if viewModel.isBackButtonVisible {
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
                        title: viewModel.buttonTitle(
                            viewModel.page,
                        ),
                        action: viewModel.onPressedNext,
                        isDisabled: viewModel.isLegalDisabled,
                    )
                    .dStyle(
                        .primaryButton,
                    )
                }
                .padding(
                    size.s16,
                )
                .animation(
                    .easeInOut,
                    value: viewModel.page,
                )
                .animation(
                    theme.animation,
                    value: viewModel.isLegalAccepted,
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

    private var stepper: some View {
        DPageIndicator(
            count: OnBoardingViewModel.Page.allCases.count,
            currentIndex: viewModel.page.index,
        )
    }

    @ViewBuilder
    private var currentPage: some View {
        switch viewModel.page {
        case .first:
            OnBoardingPageView(
                tag: .first,
                title: l10n[
                    .onBoardingFirstTitle,
                ],
                image: .doglyad,
                description: l10n[
                    .onBoardingFirstDescription,
                ],
            )
        case .second:
            OnBoardingPageView(
                tag: .second,
                title: l10n[
                    .onBoardingSecondTitle,
                ],
                image: .doglyadUSMachine,
                description: l10n[
                    .onBoardingSecondDescription,
                ],
            )
        case .third:
            OnBoardingPageView(
                tag: .third,
                title: l10n[
                    .onBoardingThirdTitle,
                ],
                image: .doglyadQuiet,
                description: l10n[
                    .onBoardingThirdDescription,
                ],
            ) {
                HStack(
                    alignment: .center,
                ) {
                    DCheckbox(
                        isChecked: Binding(
                            get: { viewModel.isLegalAccepted },
                            set: viewModel.onLegalAcceptedChanged,
                        ),
                    )
                    .padding(
                        .trailing,
                        size.s8,
                    )

                    DText(
                        viewModel.legalAttributedText(
                            theme: theme,
                            locale: locale,
                        ),
                    )
                    .multilineTextAlignment(
                        .leading,
                    )
                    .tint(
                        color.grayscaleHeader,
                    )
                    .environment(
                        \.openURL,
                        OpenURLAction { url in
                            viewModel.onLegalAttributedEnvironment(
                                url: url,
                            )
                        },
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
                .padding(
                    .top,
                    size.s16,
                )
                .padding(
                    .horizontal,
                    size.s16,
                )
            }
        case .fourth:
            OnBoardingPageView(
                tag: .fourth,
                title: l10n[
                    .onBoardingFourthTitle,
                ],
                image: .doglyadQuestion,
                description: l10n[
                    .onBoardingFourthDescription,
                ],
            )
        case .fifth:
            OnBoardingPageView(
                tag: .fifth,
                title: l10n[
                    .onBoardingFifthTitle,
                ],
                image: .doglyadTable,
                description: l10n[
                    .onBoardingFifthDescription,
                ],
            )
        }
    }
}
