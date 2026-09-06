import DoglyadUI
import SwiftUI

struct TemplateEditScreenView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: TemplateEditViewModel
    @FocusState private var focus: TemplateAddViewModel.Focus?

    var body: some View {
        DScreen(
            title: .templateEditTitle,
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
            content: { toolbarInset, _ in
                ScrollView(
                    showsIndicators: false
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
                        .padding(.bottom, size.s4)

                        DTextField(
                            controller: viewModel.templateController,
                            focus: DTextFieldFocus(
                                value: .content,
                                state: $focus
                            ),
                            title: .templateContentLabel,
                            placeholder: .templateContentPlaceholder,
                            sumbitLabel: .done
                        )
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
                        .padding(.bottom, size.s16)
                    }
                    .padding(size.s16)
                    .padding(.top, toolbarInset)
                    .padding(.bottom, size.s32)
                }
                .scrollDismissesKeyboard(.interactively)
            },
            bottom: {
                VStack(
                    spacing: .zero
                ) {
                    DButton(
                        title: .buttonSave,
                        action: viewModel.onTapSave
                    )
                    .dStyle(.primaryButton)
                    .padding(.bottom, size.s8)

                    DButton(
                        title: .templateDeleteButton,
                        action: viewModel.onTapDelete
                    )
                    .dStyle(.card)
                }
                .padding(size.s16)
            }
        )
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
