import DoglyadUI
import SwiftUI

struct SettingsScreenView: DView {
    @EnvironmentObject var theme: DTheme

    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        DScreen(
            title: .settingsTitle,
            onTapBack: viewModel.onTapBack
        ) { toolbarInset, _ in
            ScrollView(
                showsIndicators: false
            ) {
                VStack(
                    spacing: .zero
                ) {
                    VStack(
                        spacing: size.s8
                    ) {
                        DListButtonCard(
                            image: .iconHistory,
                            title: .settingsHistoryTitle,
                            description: viewModel.historyDescription(),
                            action: viewModel.onTapHistory
                        )
                        DListButtonCard(
                            image: .iconTemplates,
                            title: .settingsTemplatesTitle,
                            description: .settingsTemplatesDescription,
                            action: viewModel.onTapTemplates
                        )
                        DListButtonCard(
                            image: .iconSettings,
                            title: .settingsUserSettingsTitle,
                            description: .settingsUserSettingsDescription,
                            action: viewModel.onTapUserSettings
                        )
                        DListButtonCard(
                            image: .iconMail,
                            title: .settingsSubscriptionManageTitle,
                            description: .settingsSubscriptionManageDescription,
                            action: viewModel.onTapSubscription
                        )
                        DListButtonCard(
                            image: .iconAI,
                            title: .settingsNeuralModelTitle,
                            description: LocalizedStringResource(
                                stringLiteral: viewModel.neuralModel.title
                            ),
                            action: viewModel.onTapNeuralModelSelection
                        )
                        DListButtonCard(
                            image: .iconAISettings,
                            title: .settingsNeuralModelSettingsTitle,
                            description: .settingsNeuralModelSettingsDescription,
                            action: viewModel.onTapNeuralModelSettings
                        )
                        .paidBadge(.neuralModelSettings)
                        DListButtonCard(
                            image: .iconFile,
                            title: .settingsStorageTitle,
                            description: .settingsStorageDescription,
                            action: viewModel.onTapStorage
                        )
                        DListButtonCard(
                            image: .iconGuard,
                            title: .settingsPrivacyPolicyTitle,
                            description: .settingsPrivacyPolicyDescription,
                            action: viewModel.onTapPrivacyPolicy
                        )
                        DListButtonCard(
                            image: .iconDocuments,
                            title: .settingsTermsAndConditionsTitle,
                            description: .settingsTermsAndConditionsDescription,
                            action: viewModel.onTapTermsAndConditions
                        )
                    }
                    .padding(.bottom, size.s32)

                    DButton(
                        image: .info,
                        title: .settingsAboutAppTitle,
                        action: viewModel.onTapAboutApp
                    )
                    .dStyle(.primaryText)
                    .padding(.bottom, size.s32)
                }
                .padding(size.s16)
                .padding(.top, toolbarInset)
                .padding(.bottom, size.s32)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
