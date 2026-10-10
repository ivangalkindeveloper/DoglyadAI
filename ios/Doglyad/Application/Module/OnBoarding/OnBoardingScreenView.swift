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
        .onAppear(
            perform: viewModel.onAppear,
        )
    }

    private var stepper: some View {
        HStack(
            spacing: size.s4,
        ) {
            ForEach(
                Array(
                    OnBoardingViewModel.Page.allCases.enumerated(),
                ),
                id: \.offset,
            ) { index, _ in
                Capsule()
                    .fill(
                        index <= viewModel.page.index
                            ? color.primaryDefault
                            : color.grayscaleLine,
                    )
                    .frame(
                        height: size.s2,
                    )
            }
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch viewModel.page {
        case .first:
            OnBoardingPageView(
                tag: .first,
                title: l10n[
                    .onBoardingTitleFirst,
                ],
                image: .doglyad,
                description: l10n[
                    .onBoardingDescriptionFirst,
                ],
            )
        case .second:
            OnBoardingPageView(
                tag: .second,
                title: l10n[
                    .onBoardingTitleSecond,
                ],
                image: .doglyadUSMachine,
                description: l10n[
                    .onBoardingDescriptionSecond,
                ],
            )
        case .third:
            OnBoardingPageView(
                tag: .third,
                title: l10n[
                    .onBoardingTitleThird,
                ],
                image: .doglyadQuiet,
                description: l10n[
                    .onBoardingDescriptionThird,
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

                    Text(
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
                    .onBoardingTitleFourth,
                ],
                image: .doglyadQuestion,
                description: l10n[
                    .onBoardingDescriptionFourth,
                ],
            )
        case .fifth:
            OnBoardingPageView(
                tag: .fifth,
                title: l10n[
                    .onBoardingTitleFifth,
                ],
                image: .doglyadTable,
                description: l10n[
                    .onBoardingDescriptionFifth,
                ],
            )
        }
    }
}
