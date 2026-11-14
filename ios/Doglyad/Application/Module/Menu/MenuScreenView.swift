import DoglyadUI
import SwiftUI

struct MenuScreenView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @StateObject var viewModel: MenuViewModel

    init(
        viewModel: @autoclosure @escaping () -> MenuViewModel,
    ) {
        _viewModel = StateObject(
            wrappedValue: viewModel(),
        )
    }

    var body: some View {
        DScreen(
            title: l10n[
                .menuTitle,
            ],
            onTapBack: viewModel.onTapBack,
        ) { toolbarInset, _ in
            DScrollVStack(
                alignment: .center,
                spacing: .zero,
                padding: EdgeInsets(
                    top: size.s16 + toolbarInset,
                    leading: size.s16,
                    bottom: size.s16 + size.s32,
                    trailing: size.s16,
                ),
            ) {
                VStack(
                    spacing: size.s8,
                ) {
                    DListButtonCard(
                        image: .iconHistory,
                        title: l10n[
                            .menuHistoryTitle,
                        ],
                        description: viewModel.historyDescription,
                        action: viewModel.onTapHistory,
                    )
                    DListButtonCard(
                        image: .iconTemplates,
                        title: l10n[
                            .menuTemplatesTitle,
                        ],
                        description: l10n[
                            .menuTemplatesDescription,
                        ],
                        action: viewModel.onTapTemplates,
                    )
                    DListButtonCard(
                        image: .iconSettings,
                        title: l10n[
                            .menuWorkSettingsTitle,
                        ],
                        description: l10n[
                            .menuWorkSettingsDescription,
                        ],
                        action: viewModel.onTapWorkSettings,
                    )
                    DListButtonCard(
                        image: .iconAISettings,
                        title: l10n[
                            .menuSettingsAITitle,
                        ],
                        description: l10n[
                            .menuSettingsAIDescription,
                        ],
                        action: viewModel.onTapSettingsAI,
                    )
                    DListButtonCard(
                        image: .iconMail,
                        title: l10n[
                            .buttonSubscriptionManage,
                        ],
                        description: l10n[
                            .menuSubscriptionManageDescription,
                        ],
                        action: viewModel.onTapSubscription,
                    )
                    DListButtonCard(
                        image: .iconFile,
                        title: l10n[
                            .menuStorageTitle,
                        ],
                        description: l10n[
                            .menuStorageDescription,
                        ],
                        action: viewModel.onTapStorage,
                    )
                    DListButtonCard(
                        image: .iconGuard,
                        title: l10n[
                            .menuPrivacyPolicyTitle,
                        ],
                        description: l10n[
                            .menuPrivacyPolicyDescription,
                        ],
                        action: viewModel.onTapPrivacyPolicy,
                    )
                    DListButtonCard(
                        image: .iconDocuments,
                        title: l10n[
                            .menuTermsAndConditionsTitle,
                        ],
                        description: l10n[
                            .menuTermsAndConditionsDescription,
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
                        .menuAboutAppButton,
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
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear(
            perform: viewModel.onDisappear,
        )
        .environmentObject(
            viewModel,
        )
    }
}
