import DoglyadUI
import SwiftUI

struct UserSettingsScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: UserSettingsViewModel
    @FocusState private var focus: UserSettingsViewModel.Focus?

    var body: some View {
        DScreen(
            title: .userSettingsTitle,
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
            keyboardToolbar: {
                if focus != nil {
                    DToolbar(
                        upAccessibilityLabel: .buttonBack,
                        downAccessibilityLabel: .buttonNext,
                        doneAccessibilityLabel: .buttonDone,
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
                        DTextField(
                            controller: viewModel.emailController,
                            focus: DTextFieldFocus(
                                value: .email,
                                state: $focus
                            ),
                            title: .userSettingsEmailLabel,
                            placeholder: .userSettingsEmailPlaceholder,
                            mode: DTextFieldSingleLineMode(submitLabel: .done),
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )
                        .id(UserSettingsViewModel.Focus.email)
                        .padding(.bottom, size.s4)

                        DText(.userSettingsEmailDescription)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.horizontal, size.s8)
                            .padding(.bottom, size.s16)

                        DButtonCard(
                            action: viewModel.toggleIncludeRecommendations
                        ) {
                            HStack(alignment: .center) {
                                DText(.userSettingsRecommendationsLabel)
                                    .dStyle(font: typography.linkSmall)

                                Spacer(minLength: size.s16)

                                Toggle(
                                    "",
                                    isOn: $viewModel.includeRecommendations
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .allowsHitTesting(false)
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .foregroundStyle(color.grayscaleHeader)
                        }
                        .padding(.bottom, size.s4)

                        DText(.userSettingsRecommendationsDescription)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.horizontal, size.s8)
                    }
                    .padding(.top, toolbarInset)
                    .padding(size.s16)
                    .padding(.bottom, bottomInset)
                }
            },
            bottom: {
                DButton(
                    title: .buttonSave,
                    action: viewModel.onTapSave
                )
                .dStyle(.primaryButton)
                .padding(size.s16)
            }
        )
        .onAppear(perform: viewModel.onAppear)
        .scrollDismissesKeyboard(.interactively)
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
    }
}
