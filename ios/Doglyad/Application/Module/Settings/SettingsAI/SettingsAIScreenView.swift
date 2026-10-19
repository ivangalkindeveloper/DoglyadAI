import DoglyadUI
import SwiftUI

struct SettingsAIScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SettingsAIViewModel
    @FocusState private var focus: SettingsAIFocus?

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as SettingsAILoadingState: true
        default: false
        }

        DScreen(
            title: l10n[
                .settingsAITitle,
            ],
            onTapBack: viewModel.onTapBack,
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
                DFocusScrollView(
                    focus: focus,
                ) {
                    LazyVStack(
                        alignment: .leading,
                        spacing: .zero,
                        pinnedViews: [.sectionHeaders],
                    ) {
                        Section {
                            DListButtonCard(
                                title: l10n[
                                    .settingsAITranscriberTitle,
                                ],
                                description: l10n[
                                    viewModel.transcriberType.titleKey,
                                ],
                                action: viewModel.onTapTranscriber,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DListButtonCard(
                                title: l10n[
                                    .settingsAITranscriptParserTitle,
                                ],
                                description: l10n[
                                    viewModel.transcriptParserType.titleKey,
                                ],
                                action: viewModel.onTapTranscriptParser,
                            )
                        } header: {
                            SectionHeaderView(
                                title: l10n[
                                    .settingsAISpeechTitle,
                                ],
                            )
                        } footer: {
                            Color.clear
                                .frame(
                                    height: size.s16,
                                )
                        }

                        Section {
                            DListButtonCard(
                                image: .iconAI,
                                title: l10n[
                                    .settingsAINeuralModelTitle,
                                ],
                                description: LocalizedStringResource(
                                    stringLiteral: viewModel.neuralModel.title,
                                ),
                                action: viewModel.onTapNeuralModelSelection,
                            )
                            .contentTransition(
                                .opacity,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DButtonCard(
                                action: { viewModel.toggleIsMarkdown() },
                            ) {
                                HStack(
                                    alignment: .center,
                                ) {
                                    DText(
                                        l10n[
                                            .settingsAIMarkdownLabel,
                                        ],
                                    )
                                    .dStyle(
                                        font: typography.linkSmall,
                                    )

                                    Spacer(
                                        minLength: size.s16,
                                    )

                                    DToggle(
                                        "",
                                        isOn: .constant(
                                            viewModel.isMarkdown,
                                        ),
                                    )
                                    .labelsHidden()
                                    .toggleStyle(
                                        .switch,
                                    )
                                    .allowsHitTesting(
                                        false,
                                    )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading,
                                )
                                .foregroundStyle(
                                    color.grayscaleHeader,
                                )
                            }
                            .disabled(
                                !viewModel.isReportGenerationSettingsEnabled,
                            )
                            .paidBadge(
                                viewModel.reportGenerationSettingsAvailability,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DText(
                                l10n[
                                    .settingsAIMarkdownDescription,
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

                            DTextField(
                                inputTextController: viewModel.temperatureTextController,
                                focus: DTextFieldFocus(
                                    value: .temperature,
                                    state: $focus,
                                ),
                                title: l10n[
                                    .settingsAITemperatureLabel,
                                ],
                                placeholder: l10n[
                                    .settingsAITemperaturePlaceholder,
                                ],
                                mode: DTextFieldSingleLineMode(
                                    submitLabel: .next,
                                ),
                                keyboardType: .decimalPad,
                            )
                            .disabled(
                                !viewModel.isReportGenerationSettingsEnabled,
                            )
                            .paidBadge(
                                viewModel.reportGenerationSettingsAvailability,
                            )
                            .id(
                                SettingsAIFocus.temperature,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DText(
                                l10n[
                                    .settingsAITemperatureDescription,
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

                            DTextField(
                                inputTextController: viewModel.maxTokensTextController,
                                focus: DTextFieldFocus(
                                    value: .length,
                                    state: $focus,
                                ),
                                title: l10n[
                                    .settingsAIMaxTokensLabel,
                                ],
                                placeholder: l10n[
                                    .settingsAIMaxTokensPlaceholder,
                                ],
                                mode: DTextFieldSingleLineMode(
                                    submitLabel: .done,
                                ),
                                keyboardType: .numberPad,
                            )
                            .disabled(
                                !viewModel.isReportGenerationSettingsEnabled,
                            )
                            .paidBadge(
                                viewModel.reportGenerationSettingsAvailability,
                            )
                            .id(
                                SettingsAIFocus.length,
                            )
                            .padding(
                                .bottom,
                                size.s4,
                            )

                            DText(
                                l10n[
                                    .settingsAIMaxTokensDescription,
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
                        } header: {
                            SectionHeaderView(
                                title: l10n[
                                    .settingsAIReportGenerationTitle,
                                ],
                            )
                        }
                    }
                    .padding(
                        size.s16,
                    )
                    .disabled(
                        isProcessing,
                    )
                }
                .contentMargins(
                    .top,
                    toolbarInset,
                    for: .scrollContent,
                )
                .contentMargins(
                    .bottom,
                    bottomInset,
                    for: .scrollContent,
                )
            },
            bottom: {
                DButton(
                    title: l10n[
                        .buttonSave,
                    ],
                    action: viewModel.onTapSave,
                    isLoading: isProcessing,
                )
                .dStyle(
                    .primaryButton,
                )
                .padding(
                    size.s16,
                )
            },
        )
        .environmentObject(
            viewModel,
        )
        .onAppear(
            perform: viewModel.onAppear,
        )
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
        .scrollDismissesKeyboard(
            .interactively,
        )
    }
}
