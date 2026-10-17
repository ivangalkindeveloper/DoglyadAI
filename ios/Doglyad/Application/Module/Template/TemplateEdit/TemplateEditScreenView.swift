import DoglyadUI
import SwiftUI

struct TemplateEditScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: TemplateEditViewModel
    @FocusState private var focus: TemplateEditFocus?

    var body: some View {
        let isSaveDisabled = switch viewModel.state {
        case _ as TemplateEditInitializationFailedState: true
        default: false
        }

        let isProcessing = switch viewModel.state {
        case _ as TemplateEditLoadingState: true
        default: false
        }

        DScreen(
            title: l10n[
                .templateEditTitle,
            ],
            onTapBack: viewModel.onTapBack,
            trailing: {
                DButton(
                    image: .delete,
                    action: viewModel.onTapDelete,
                )
                .dStyle(
                    .circle,
                )
                .disabled(
                    isProcessing,
                )
            },
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: l10n[
                            .buttonBack,
                        ],
                        downAccessibilityLabel: l10n[
                            .buttonNext,
                        ],
                        doneAccessibilityLabel: l10n[
                            .buttonDone,
                        ],
                        onTapUp: viewModel.isPreviousFieldFocusable ? { viewModel.onTapToolbarUp() } : nil,
                        onTapDown: viewModel.isNextFieldFocusable ? { viewModel.onTapToolbarDown() } : nil,
                        onTapDone: viewModel.unfocus,
                        trailButtons: [
                            DToolbarButton(
                                accessibilityLabel: l10n[
                                    .buttonSave,
                                ],
                                style: .primaryDefault,
                                content: .text(
                                    l10n[
                                        .buttonSave,
                                    ],
                                ),
                                action: viewModel.onTapSave,
                            ),
                        ],
                    )
                    .disabled(
                        isProcessing,
                    )
                }
            },
            content: { toolbarInset, bottomInset in
                switch viewModel.state {
                case _ as TemplateEditInitializationFailedState:
                    LoadingErrorView(
                        onRetry: viewModel.onTapRetryInitialization,
                    )
                default:
                    DFocusScrollView(
                        focus: focus,
                    ) {
                        VStack(
                            alignment: .leading,
                            spacing: .zero,
                        ) {
                            DListButtonCard(
                                title: l10n[
                                    .templateExaminationTypeLabel,
                                ],
                                description: viewModel.usExaminationType.localizedTitle,
                                action: viewModel.onTapExaminationType,
                            )
                            .contentTransition(
                                .opacity,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DTextField(
                                controller: viewModel.nameController,
                                focus: DTextFieldFocus(
                                    value: .name,
                                    state: $focus,
                                ),
                                title: l10n[
                                    .templateNameLabel,
                                ],
                                placeholder: l10n[
                                    .templateNamePlaceholder,
                                ],
                                mode: DTextFieldSingleLineMode(
                                    submitLabel: .next,
                                ),
                            )
                            .id(
                                TemplateEditFocus.name,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DTextField(
                                controller: viewModel.templateController,
                                focus: DTextFieldFocus(
                                    value: .content,
                                    state: $focus,
                                ),
                                title: l10n[
                                    .templateContentLabel,
                                ],
                                placeholder: l10n[
                                    .templateContentPlaceholder,
                                ],
                                mode: DTextFieldMultiLineMode(),
                            )
                            .id(
                                TemplateEditFocus.content,
                            )
                            .padding(
                                .bottom,
                                size.s8,
                            )

                            VStack(
                                alignment: .leading,
                                spacing: .zero,
                            ) {
                                DText(
                                    l10n[
                                        .templateContentDescription,
                                    ],
                                )
                                .dStyle(
                                    font: typography.textXSmall,
                                    color: color.grayscalePlacehold,
                                )
                                .padding(
                                    .horizontal,
                                    size.s8,
                                )
                                .padding(
                                    .bottom,
                                    size.s8,
                                )

                                DText(
                                    l10n[
                                        .templateExampleDescription,
                                    ],
                                )
                                .dStyle(
                                    font: typography.textXSmall,
                                    color: color.grayscalePlacehold,
                                )
                                .padding(
                                    size.s8,
                                )
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading,
                                )
                                .background(
                                    color.grayscaleInput.opacity(
                                        0.6,
                                    ),
                                )
                                .cornerRadius(
                                    size.s12,
                                )
                            }
                            .padding(
                                .horizontal,
                                size.s4,
                            )
                            .padding(
                                .bottom,
                                size.s16,
                            )
                        }
                        .padding(
                            .top,
                            toolbarInset + size.s8,
                        )
                        .padding(
                            .horizontal,
                            size.s16,
                        )
                        .padding(
                            .bottom,
                            bottomInset + size.s16,
                        )
                        .disabled(
                            isProcessing,
                        )
                    }
                    .scrollDismissesKeyboard(
                        .interactively,
                    )
                }
            },
            bottom: {
                DButton(
                    title: l10n[
                        .buttonSave,
                    ],
                    action: viewModel.onTapSave,
                    isLoading: isProcessing,
                    isDisabled: isSaveDisabled,
                )
                .dStyle(
                    .primaryButton,
                )
                .padding(
                    size.s16,
                )
            },
        )
        .onAppear {
            viewModel.onAppear()
        }
        .onSubmit {
            viewModel.onSubmit()
        }
        .onChange(
            of: focus,
            initial: true,
        ) { _, newValue in
            guard viewModel.focus != newValue else { return }
            viewModel.onFocusChanged(
                newValue,
            )
        }
        .onChange(
            of: viewModel.focus,
            initial: true,
        ) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .environmentObject(
            viewModel,
        )
    }
}
