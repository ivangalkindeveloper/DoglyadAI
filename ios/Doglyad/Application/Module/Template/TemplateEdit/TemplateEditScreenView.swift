import DoglyadUI
import SwiftUI

struct TemplateEditScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: TemplateEditViewModel
    @FocusState private var focus: TemplateEditFocus?

    var body: some View {
        let (isSaveDisabled, isProcessing) = switch viewModel.state {
        case _ as TemplateEditInitializationFailedState: (true, false)
        case _ as TemplateEditLoadingState: (false, true)
        default: (false, false)
        }

        DScreen(
            title: l10n[
                .templateEditTitle,
            ],
            onTapBack: viewModel.onTapBack,
            trailing: {
                DButton(
                    image: .delete,
                    accessibilityIdentifier: "template.delete",
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
                        onTapUp: viewModel.isPreviousFieldFocusable ? {
                            viewModel.onTapToolbarUp()
                        } : nil,
                        onTapDown: viewModel.isNextFieldFocusable ? {
                            viewModel.onTapToolbarDown()
                        } : nil,
                        onTapDone: viewModel.unfocus,
                        trailButtons: [
                            DToolbarButton(
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
                TemplateEditContentView(
                    focus: $focus,
                    toolbarInset: toolbarInset,
                    bottomInset: bottomInset,
                    isProcessing: isProcessing,
                )
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
        .environmentObject(
            viewModel,
        )
    }
}
