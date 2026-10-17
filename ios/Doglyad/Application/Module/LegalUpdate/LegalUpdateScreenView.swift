import DoglyadUI
import SwiftUI

struct LegalUpdateScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @Environment(
        \.locale,
    ) private var locale
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: LegalUpdateViewModel

    var body: some View {
        let isDisabled: Bool = switch viewModel.state {
        case _ as LegalUpdateLoadingState: true
        default: !viewModel.isLegalAccepted
        }
        let isProcessing = switch viewModel.state {
        case _ as LegalUpdateLoadingState: true
        default: false
        }

        DScreen(
            title: l10n[
                .legalUpdateTitle,
            ],
            content: { toolbarHeight, bottomHeight in
                VStack(
                    alignment: .leading,
                    spacing: size.s16,
                ) {
                    Spacer()

                    DImage(
                        .doglyadQuiet,
                    )
                    .scaledToFit()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center,
                    )
                    .padding(
                        size.s16,
                    )

                    Spacer()

                    DText(
                        l10n[
                            .legalUpdateDescription,
                        ],
                    )
                    .dStyle(
                        font: typography.textMedium,
                    )

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
                        size.s8,
                    )
                }
                .padding(
                    .top,
                    toolbarHeight,
                )
                .padding(
                    size.s16,
                )
                .padding(
                    .bottom,
                    bottomHeight,
                )
            },
            bottom: {
                DButton(
                    title: l10n[
                        .buttonAccept,
                    ],
                    action: viewModel.onTapAccept,
                    isLoading: isProcessing,
                    isDisabled: isDisabled,
                )
                .dStyle(
                    .primaryButton,
                )
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
