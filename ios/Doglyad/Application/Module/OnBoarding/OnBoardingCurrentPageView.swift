import DoglyadUI
import SwiftUI

struct OnBoardingCurrentPageView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: OnBoardingViewModel

    var body: some View {
        switch viewModel.state {
        case _ as OnBoardingFirstState:
            OnBoardingPageView(
                tag: 0,
                title: l10n[
                    .onBoardingFirstTitle,
                ],
                image: .doglyad,
                description: l10n[
                    .onBoardingFirstDescription,
                ],
            )
        case _ as OnBoardingSecondState:
            OnBoardingPageView(
                tag: 1,
                title: l10n[
                    .onBoardingSecondTitle,
                ],
                image: .doglyadUSMachine,
                description: l10n[
                    .onBoardingSecondDescription,
                ],
            )
        case let state as OnBoardingLegalState:
            OnBoardingPageView(
                tag: 2,
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
                            get: { state.isLegalAccepted },
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
        case _ as OnBoardingExaminationTypeState:
            OnBoardingPageView(
                tag: 3,
                title: l10n[
                    .onBoardingFourthTitle,
                ],
                image: .doglyadQuestion,
                description: l10n[
                    .onBoardingFourthDescription,
                ],
            )
        case _ as OnBoardingFinalState, _ as OnBoardingCompletingState, _ as OnBoardingFailedState:
            OnBoardingPageView(
                tag: 4,
                title: l10n[
                    .onBoardingFifthTitle,
                ],
                image: .doglyadTable,
                description: l10n[
                    .onBoardingFifthDescription,
                ],
            )
        default: EmptyView()
        }
    }
}
