import DoglyadUI
import SwiftUI

struct NeuralModelSettingsScreenView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @StateObject var viewModel: NeuralModelSettingsViewModel
    @FocusState private var focus: NeuralModelSettingsViewModel.Focus?

    var body: some View {
        DScreen(
            title: .neuralModelSettingsTitle,
            onTapBack: viewModel.onTapBack,
            content: { toolbarInset, _ in
                ScrollView(
                    showsIndicators: false
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
                            keyboardType: .decimalPad,
                            sumbitLabel: .next
                        )
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
                            keyboardType: .numberPad,
                            sumbitLabel: .done
                        )
                        .padding(.bottom, size.s4)

                        DText(.neuralModelMaxTokensDescription)
                            .dStyle(
                                font: typography.textXSmall,
                                color: color.grayscalePlacehold
                            )
                            .padding(.horizontal, size.s8)
                    }
                    .padding(size.s16)
                    .padding(.top, toolbarInset)
                    .padding(.bottom, size.s64)
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
        .onTapGesture {
            viewModel.unfocus()
        }
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
