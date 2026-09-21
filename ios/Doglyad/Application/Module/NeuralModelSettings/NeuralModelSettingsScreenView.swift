import DoglyadUI
import SwiftUI

struct NeuralModelSettingsScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: NeuralModelSettingsViewModel
    @FocusState private var focus: NeuralModelSettingsViewModel.Focus?

    var body: some View {
        DScreen(
            title: .neuralModelSettingsTitle,
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
                        DButtonCard(
                            action: { viewModel.toggleIsMarkdown() }
                        ) {
                            HStack(alignment: .center) {
                                DText(.neuralModelMarkdownLabel)
                                    .dStyle(
                                        font: typography.linkSmall
                                    )

                                Spacer(minLength: size.s16)

                                Toggle(
                                    "",
                                    isOn: $viewModel.isMarkdown
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

                        DText(.neuralModelMarkdownDescription)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.horizontal, size.s8)
                            .padding(.bottom, size.s16)

                        DTextField(
                            controller: viewModel.temperatureController,
                            focus: DTextFieldFocus(
                                value: .temperature,
                                state: $focus
                            ),
                            title: .neuralModelTemperatureLabel,
                            placeholder: .neuralModelTemperaturePlaceholder,
                            mode: DTextFieldSingleLineMode(submitLabel: .next),
                            keyboardType: .decimalPad
                        )
                        .id(NeuralModelSettingsViewModel.Focus.temperature)
                        .padding(.bottom, size.s4)

                        DText(.neuralModelTemperatureDescription)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.horizontal, size.s8)
                            .padding(.bottom, size.s16)

                        DTextField(
                            controller: viewModel.maxTokensController,
                            focus: DTextFieldFocus(
                                value: .length,
                                state: $focus
                            ),
                            title: .neuralModelMaxTokensLabel,
                            placeholder: .neuralModelMaxTokensPlaceholder,
                            mode: DTextFieldSingleLineMode(submitLabel: .done),
                            keyboardType: .numberPad
                        )
                        .id(NeuralModelSettingsViewModel.Focus.length)
                        .padding(.bottom, size.s4)

                        DText(.neuralModelMaxTokensDescription)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.horizontal, size.s8)
                    }
                    .padding(.top, toolbarInset)
                    .padding(size.s16)
                    .padding(.bottom, bottomInset)
                    .disabled(viewModel.isLoading)
                }
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
        .scrollDismissesKeyboard(.interactively)
    }
}
