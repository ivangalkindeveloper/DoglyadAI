import DoglyadUI
import SwiftUI

struct SettingsScreenView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        DScreen(
            title: l10n[
                .settingsTitle,
            ],
            onTapBack: viewModel.onTapBack,
        ) { toolbarInset, _ in
            ScrollView(
                showsIndicators: false,
            ) {
                VStack(
                    spacing: .zero,
                ) {
                    VStack(
                        spacing: size.s8,
                    ) {
                        DListButtonCard(
                            image: .iconHistory,
                            title: l10n[
                                .settingsHistoryTitle,
                            ],
                            description: viewModel.historyDescription(),
                            action: viewModel.onTapHistory,
                        )
                        .contentTransition(
                            .opacity,
                        )
                        DListButtonCard(
                            image: .iconTemplates,
                            title: l10n[
                                .settingsTemplatesTitle,
                            ],
                            description: l10n[
                                .settingsTemplatesDescription,
                            ],
                            action: viewModel.onTapTemplates,
                        )
                        DListButtonCard(
                            image: .iconSettings,
                            title: l10n[
                                .settingsUserSettingsTitle,
                            ],
                            description: l10n[
                                .settingsUserSettingsDescription,
                            ],
                            action: viewModel.onTapUserSettings,
                        )
                        DListButtonCard(
                            image: .iconMail,
                            title: l10n[
                                .settingsSubscriptionManageTitle,
                            ],
                            description: l10n[
                                .settingsSubscriptionManageDescription,
                            ],
                            action: viewModel.onTapSubscription,
                        )
                        DListButtonCard(
                            image: .iconAI,
                            title: l10n[
                                .settingsNeuralModelTitle,
                            ],
                            description: LocalizedStringResource(
                                stringLiteral: viewModel.neuralModel.title,
                            ),
                            action: viewModel.onTapNeuralModelSelection,
                        )
                        .contentTransition(
                            .opacity,
                        )
                        DListButtonCard(
                            image: .iconAISettings,
                            title: l10n[
                                .settingsNeuralModelSettingsTitle,
                            ],
                            description: l10n[
                                .settingsNeuralModelSettingsDescription,
                            ],
                            action: viewModel.onTapNeuralModelSettings,
                        )
                        .paidBadge(
                            .neuralModelSettings,
                        )
                        DListButtonCard(
                            image: .iconFile,
                            title: l10n[
                                .settingsStorageTitle,
                            ],
                            description: l10n[
                                .settingsStorageDescription,
                            ],
                            action: viewModel.onTapStorage,
                        )
                        DListButtonCard(
                            image: .iconGuard,
                            title: l10n[
                                .settingsPrivacyPolicyTitle,
                            ],
                            description: l10n[
                                .settingsPrivacyPolicyDescription,
                            ],
                            action: viewModel.onTapPrivacyPolicy,
                        )
                        DListButtonCard(
                            image: .iconDocuments,
                            title: l10n[
                                .settingsTermsAndConditionsTitle,
                            ],
                            description: l10n[
                                .settingsTermsAndConditionsDescription,
                            ],
                            action: viewModel.onTapTermsAndConditions,
                        )
                    }
                    .padding(
                        .bottom,
                        size.s32,
                    )

                    DButton(
                        image: .info,
                        title: l10n[
                            .settingsAboutAppTitle,
                        ],
                        action: viewModel.onTapAboutApp,
                    )
                    .dStyle(
                        .primaryText,
                    )
                    .padding(
                        .bottom,
                        size.s32,
                    )
                }
                .padding(
                    size.s16,
                )
                .padding(
                    .top,
                    toolbarInset,
                )
                .padding(
                    .bottom,
                    size.s32,
                )
                .animation(
                    theme.animation,
                    value: viewModel.reportsCount,
                )
                .animation(
                    theme.animation,
                    value: viewModel.neuralModel.id,
                )
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(
            viewModel,
        )
    }
}
