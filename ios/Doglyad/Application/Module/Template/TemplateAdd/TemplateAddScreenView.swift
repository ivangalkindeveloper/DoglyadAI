import DoglyadUI
import SwiftUI

struct TemplateAddScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: TemplateAddViewModel
    @FocusState private var focus: TemplateAddViewModel.Focus?

    var body: some View {
        DScreen(
            title: .templateAddTitle,
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: .buttonBack,
                        downAccessibilityLabel: .buttonNext,
                        doneAccessibilityLabel: .buttonDone,
                        onTapUp: viewModel.canFocusPreviousField ? { viewModel.onTapToolbarUp() } : nil,
                        onTapDown: viewModel.canFocusNextField ? { viewModel.onTapToolbarDown() } : nil,
                        onTapDone: viewModel.unfocus,
                        trailButtons: [
                            DToolbarButton(
                                accessibilityLabel: .buttonSave,
                                style: .primaryDefault,
                                content: .text(.buttonSave),
                                action: viewModel.onTapSave
                            ),
                        ]
                    )
                    .disabled(viewModel.isLoading)
                }
            },
            content: { toolbarInset, bottomInset in
                DFocusScrollView(
                    focus: focus
                ) {
                    VStack(
                        alignment: .leading,
                        spacing: .zero
                    ) {
                        DListButtonCard(
                            title: .templateExaminationTypeLabel,
                            description: viewModel.usExaminationType.getLocalizedTitle(for: Locale.current),
                            action: viewModel.onTapExaminationType
                        )
                        .contentTransition(.opacity)
                        .animation(
                            theme.animation,
                            value: viewModel.usExaminationType.id
                        )
                        .padding(.bottom, size.s4)

                        DTextField(
                            controller: viewModel.nameController,
                            focus: DTextFieldFocus(
                                value: .name,
                                state: $focus
                            ),
                            title: .templateNameLabel,
                            placeholder: .templateNamePlaceholder,
                            mode: DTextFieldSingleLineMode(submitLabel: .next)
                        )
                        .id(TemplateAddViewModel.Focus.name)
                        .padding(.bottom, size.s4)

                        DTextField(
                            controller: viewModel.templateController,
                            focus: DTextFieldFocus(
                                value: .content,
                                state: $focus
                            ),
                            title: .templateContentLabel,
                            placeholder: .templateContentPlaceholder,
                            mode: DTextFieldMultiLineMode()
                        )
                        .id(TemplateAddViewModel.Focus.content)
                        .padding(.bottom, size.s8)

                        VStack(
                            alignment: .leading,
                            spacing: .zero
                        ) {
                            DText(.templateContentDescription)
                                .dStyle(
                                    font: typography.textXSmall,
                                    color: color.grayscalePlacehold
                                )
                                .padding(.horizontal, size.s8)
                                .padding(.bottom, size.s8)

                            DText(.templateExampleDescription)
                                .dStyle(
                                    font: typography.textXSmall,
                                    color: color.grayscalePlacehold
                                )
                                .padding(size.s8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(color.grayscaleInput.opacity(0.6))
                                .cornerRadius(size.s12)
                        }
                        .padding(.horizontal, size.s4)
                        .padding(.bottom, size.s8)

                        DButton(
                            title: .templateAddReadyMadeTemplatesButton,
                            action: viewModel.onTapReadyMadeTemplates
                        )
                        .dStyle(.card)
                        .padding(.bottom, size.s16)
                    }
                    .padding(.top, toolbarInset + size.s8)
                    .padding(.horizontal, size.s16)
                    .padding(.bottom, bottomInset + size.s16)
                    .disabled(viewModel.isLoading)
                }
                .scrollDismissesKeyboard(.interactively)
            },
            bottom: {
                DButton(
                    title: .buttonSave,
                    action: viewModel.onTapSave,
                    isLoading: viewModel.isLoading
                )
                .dStyle(.primaryButton)
                .padding(size.s16)
            }
        )
        .onAppear(perform: viewModel.onAppear)
        .onSubmit {
            viewModel.onSubmit()
        }
        .onChange(of: focus, initial: true) { _, newValue in
            guard viewModel.focus != newValue else { return }
            viewModel.focus = newValue
        }
        .onChange(of: viewModel.focus, initial: true) { _, newValue in
            guard focus != newValue else { return }
            focus = newValue
        }
        .environmentObject(viewModel)
    }
}
