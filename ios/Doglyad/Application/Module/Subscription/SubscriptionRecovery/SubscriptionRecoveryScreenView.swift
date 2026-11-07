import DoglyadUI
import SwiftUI

struct SubscriptionRecoveryScreenView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @StateObject var viewModel: SubscriptionRecoveryViewModel
    @FocusState private var focus: SubscriptionRecoveryFocus?

    var body: some View {
        DScreen(
            title: l10n[
                .subscriptionRecoveryTitle,
            ],
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
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
                    .disabled(
                        viewModel.isProcessing,
                    )
                }
            },
            content: { toolbarInset, bottomInset in
                DFocusScrollView(
                    focus: focus,
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: size.s24,
                    ) {
                        DText(
                            l10n[
                                .subscriptionRecoveryDescription,
                            ],
                        ).dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleLabel,
                        )
                        VStack(
                            alignment: .leading,
                            spacing: size.s12,
                        ) {
                            SectionHeaderView(
                                title: l10n[
                                    .subscriptionRecoverySaveTitle,
                                ],
                            )
                            DListButtonCard(
                                image: .iconGuard,
                                title: l10n[
                                    .subscriptionRecoveryCreateButton,
                                ],
                                description: l10n[
                                    .subscriptionRecoveryCreateDescription,
                                ],
                                action: viewModel.onTapCreateKey,
                            )
                            SubscriptionRecoveryStateView(
                                state: viewModel.state,
                            )
                        }
                        VStack(
                            alignment: .leading,
                            spacing: size.s12,
                        ) {
                            SectionHeaderView(
                                title: l10n[
                                    .subscriptionRecoveryRestoreTitle,
                                ],
                            )
                            DText(
                                l10n[
                                    .subscriptionRecoveryRestoreDescription,
                                ],
                            ).dStyle(
                                font: typography.textSmall,
                                color: color.grayscaleLabel,
                            )
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
                            )
                            .accessibilityIdentifier(
                                "subscriptionRecovery.input",
                            )
                            .privacySensitive().id(
                                SubscriptionRecoveryFocus.key,
                            )
                        }
                    }.disabled(
                        viewModel.isProcessing,
                    )
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
                    isDisabled: !viewModel.isRestoreEnabled,
                )
                .dStyle(
                    .primaryButton,
                ).padding(
                    size.s16,
                )
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
