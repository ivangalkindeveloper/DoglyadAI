import DoglyadUI
import SwiftUI

struct WorkSettingsScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: WorkSettingsViewModel
    @FocusState private var focus: WorkSettingsFocus?

    init(
        viewModel: @autoclosure @escaping () -> WorkSettingsViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .workSettingsTitle,
            ],
            onTapBack: viewModel.onTapBack,
            onTapBody: viewModel.unfocus,
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
                                .workSettingsEmailLabel,
                            ],
                            placeholder: l10n[
                                .workSettingsEmailPlaceholder,
                            ],
                            mode: DTextFieldSingleLineMode(
                                submitLabel: .done,
                            ),
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                        )
                        .id(
                            WorkSettingsFocus.email,
                        )
                        .padding(
                            .bottom,
                            size.s4,
                        )

                        DText(
                            l10n[
                                .workSettingsEmailDescription,
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

                        DToggleCard(
                            title: l10n[
                                .workSettingsPatientConsentLabel,
                            ],
                            description: l10n[
                                .workSettingsPatientConsentDescription,
                            ],
                            isOn: .constant(
                                viewModel.isNeedPatientConsent,
                            ),
                            action: viewModel.togglePatientConsent,
                            accessibilityIdentifier: "userSettings.patientConsent",
                        )
                        .padding(
                            .bottom,
                            size.s16,
                        )

                        DToggleCard(
                            title: l10n[
                                .workSettingsRecommendationsLabel,
                            ],
                            description: l10n[
                                .workSettingsRecommendationsDescription,
                            ],
                            isOn: .constant(
                                viewModel.isRecommendationsIncluded,
                            ),
                            action: viewModel.toggleRecommendationsIncluded,
                            accessibilityIdentifier: "userSettings.recommendations",
                        )
                        .padding(
                            .bottom,
                            size.s16,
                        )

                        DToggleCard(
                            title: l10n[
                                .workSettingsPhotoRemarksLabel,
                            ],
                            description: l10n[
                                .workSettingsPhotoRemarksDescription,
                            ],
                            isOn: .constant(
                                viewModel.isPhotoRemarks,
                            ),
                            action: viewModel.togglePhotoRemarks,
                            accessibilityIdentifier: "userSettings.photoRemarks",
                        )
                        .padding(
                            .bottom,
                            size.s16,
                        )

                        DToggleCard(
                            title: l10n[
                                .workSettingsDescriptionRemarksLabel,
                            ],
                            description: l10n[
                                .workSettingsDescriptionRemarksDescription,
                            ],
                            isOn: .constant(
                                viewModel.isDescriptionRemarks,
                            ),
                            action: viewModel.toggleDescriptionRemarks,
                            accessibilityIdentifier: "userSettings.descriptionRemarks",
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
                }
            },
            bottom: {
                DButton(
                    title: l10n[
                        .buttonSave,
                    ],
                    action: viewModel.onTapSave,
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
    }
}
