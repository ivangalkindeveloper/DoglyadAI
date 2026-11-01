import DoglyadUI
import SwiftUI

struct TemplateEditContentView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: TemplateEditViewModel
    let focus: FocusState<TemplateEditFocus?>.Binding
    let toolbarInset: CGFloat
    let bottomInset: CGFloat
    let isProcessing: Bool

    var body: some View {
        switch viewModel.state {
        case _ as TemplateEditInitializationFailedState:
            LoadingErrorView(
                onRetry: viewModel.onTapRetryInitialization,
            )
        default:
            DFocusScrollView(
                focus: focus.wrappedValue,
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
                        inputTextController: viewModel.nameTextController,
                        focus: DTextFieldFocus(
                            value: .name,
                            state: focus,
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
                        inputTextController: viewModel.templateTextController,
                        focus: DTextFieldFocus(
                            value: .content,
                            state: focus,
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
    }
}
