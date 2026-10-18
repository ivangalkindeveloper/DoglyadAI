import DoglyadUI
import SwiftUI

struct UserSettingsScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: UserSettingsViewModel
    @FocusState private var focus: UserSettingsFocus?

    var body: some View {
        let isProcessing = switch viewModel.state {
        case _ as UserSettingsLoadingState: true
        default: false
        }

        DScreen(
            title: l10n[
                .userSettingsTitle,
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
                    VStack(
                        alignment: .leading,
                        spacing: .zero,
                    ) {
                        DTextField(
                            inputTextController: viewModel.emailTextController,
                            focus: DTextFieldFocus(
                                value: .email,
                                state: $focus,
                            ),
                            title: l10n[
                                .userSettingsEmailLabel,
                            ],
                            placeholder: l10n[
                                .userSettingsEmailPlaceholder,
                            ],
                            mode: DTextFieldSingleLineMode(
                                submitLabel: .done,
                            ),
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                        )
                        .id(
                            UserSettingsFocus.email,
                        )
                        .padding(
                            .bottom,
                            size.s4,
                        )

                        DText(
                            l10n[
                                .userSettingsEmailDescription,
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
                            size.s16,
                        )

                        UserSettingsToggleView(
                            title: l10n[
                                .userSettingsRecommendationsLabel,
                            ],
                            description: l10n[
                                .userSettingsRecommendationsDescription,
                            ],
                            isOn: .constant(
                                viewModel.isRecommendationsIncluded,
                            ),
                            action: viewModel.toggleRecommendationsIncluded,
                        )
                        .padding(
                            .bottom,
                            size.s16,
                        )

                        UserSettingsToggleView(
                            title: l10n[
                                .userSettingsPhotoRemarksLabel,
                            ],
                            description: l10n[
                                .userSettingsPhotoRemarksDescription,
                            ],
                            isOn: .constant(
                                viewModel.isPhotoRemarks,
                            ),
                            action: viewModel.togglePhotoRemarks,
                        )
                        .padding(
                            .bottom,
                            size.s16,
                        )

                        UserSettingsToggleView(
                            title: l10n[
                                .userSettingsDescriptionRemarksLabel,
                            ],
                            description: l10n[
                                .userSettingsDescriptionRemarksDescription,
                            ],
                            isOn: .constant(
                                viewModel.isDescriptionRemarks,
                            ),
                            action: viewModel.toggleDescriptionRemarks,
                        )
                    }
                    .padding(
                        .top,
                        toolbarInset,
                    )
                    .padding(
                        size.s16,
                    )
                    .padding(
                        .bottom,
                        bottomInset,
                    )
                    .disabled(
                        isProcessing,
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
        .scrollDismissesKeyboard(
            .interactively,
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
    }
}
