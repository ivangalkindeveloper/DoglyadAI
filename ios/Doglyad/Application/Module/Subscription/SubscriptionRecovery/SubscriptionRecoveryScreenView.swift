import DoglyadUI
import SwiftUI

struct SubscriptionRecoveryScreenView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @StateObject var viewModel: SubscriptionRecoveryViewModel
    @FocusState private var focus: SubscriptionRecoveryFocus?

    init(
        viewModel: @autoclosure @escaping () -> SubscriptionRecoveryViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .subscriptionRecoveryTitle,
            ],
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
            content: { toolbarInset, bottomInset in
                DFocusScrollView(
                    focus: focus,
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: size.s16,
                    ) {
                        DTextField(
                            inputTextController: viewModel.recoveryTextController,
                            focus: DTextFieldFocus(
                                value: .key,
                                state: $focus,
                            ),
                            title: l10n[
                                .subscriptionRecoveryKeyLabel,
                            ],
                            placeholder: l10n[
                                .subscriptionRecoveryKeyPlaceholder,
                            ],
                            keyboardType: .asciiCapable,
                            autocapitalization: .never,
                            accessibilityIdentifier: "subscriptionRecovery.input",
                        )
                        .privacySensitive().id(
                            SubscriptionRecoveryFocus.key,
                        )

                        DText(
                            l10n[
                                .subscriptionRecoveryRestoreDescription,
                            ],
                        ).dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleLabel,
                        )
                        .padding(
                            .horizontal,
                            size.s8,
                        )
                    }
                    .padding(
                        .horizontal,
                        size.s16,
                    ).padding(
                        .top,
                        toolbarInset + size.s16,
                    ).padding(
                        .bottom,
                        bottomInset + size.s24,
                    )
                }.scrollDismissesKeyboard(
                    .interactively,
                )
            },
            bottom: {
                DButton(
                    title: l10n[
                        .subscriptionRecoveryRestoreButton,
                    ],
                    action: viewModel.onTapRestore,
                    isLoading: viewModel.isProcessing,
                )
                .dStyle(
                    .primaryButton,
                ).padding(
                    size.s16,
                )
            },
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        onTapDone: viewModel.unfocus,
                        trailButtons: [DToolbarButton(
                            style: .primaryDefault,
                            content: .text(
                                l10n[
                                    .subscriptionRecoveryRestoreButton,
                                ],
                            ),
                            action: viewModel.onTapRestore,
                        )],
                    )
                }
            },
        )
        .environmentObject(
            viewModel,
        ).onAppear(
            perform: viewModel.onAppear,
        ).onDisappear(
            perform: viewModel.onDisappear,
        )
        .onChange(
            of: focus,
            initial: true,
        ) { _, newValue in
            guard viewModel.focus != newValue else {
                return
            }
            viewModel.onFocusChanged(
                newValue,
            )
        }
        .onChange(
            of: viewModel.focus,
            initial: true,
        ) { _, newValue in
            guard focus != newValue else {
                return
            }
            focus = newValue
        }
        .onSubmit(
            viewModel.onTapRestore,
        )
    }
}
