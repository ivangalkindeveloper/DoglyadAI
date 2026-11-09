import DoglyadUI
import SwiftUI

struct TemplateEditScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: TemplateEditViewModel
    @FocusState private var focus: TemplateEditFocus?

    var body: some View {
        let (title, action, isDeleteDisabled): (L10NKey, () -> Void, Bool) = switch viewModel.state {
        case _ as TemplateEditInitializationErrorState: (.buttonUpdate, viewModel.onTapRetryInitialization, true)
        default: (.buttonSave, viewModel.onTapSave, false)
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
                    isDisabled:
                    isDeleteDisabled,
                    accessibilityIdentifier: "template.delete",
                )
                .dStyle(
                    .circle,
                )
            },
            onTapBody: viewModel.unfocus,
            content: { toolbarInset, bottomInset in
                TemplateEditContentView(
                    focus: $focus,
                    toolbarInset: toolbarInset,
                    bottomInset: bottomInset,
                    isProcessing: false,
                )
            },
            bottom: {
                DButton(
                    title: l10n[
                        title,
                    ],
                    action: action,
                )
                .dStyle(
                    .primaryButton,
                )
                .padding(
                    size.s16,
                )
            },
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
                }
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
