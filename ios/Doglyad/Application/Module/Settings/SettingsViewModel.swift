import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class SettingsViewModel: DViewModel {
    private let onNeuralModelSelected: (USExaminationNeuralModel) -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        initialNeuralModel: USExaminationNeuralModel,
        subscription: SubscriptionViewModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.onNeuralModelSelected = onNeuralModelSelected
        neuralModel = initialNeuralModel
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.settings)
        )
    }

    @Published var conclusionsCount = 0
    @Published var neuralModel: USExaminationNeuralModel

    override func onInit() {
        handle {
            await self.container.ultrasoundConclusionRepository.getConclusionsCount()
        } onMainSuccess: { conclusionsCount in
            self.conclusionsCount = conclusionsCount
        }
    }

    func onTapBack() {
        analytics.buttonTapped(.settingsBack)
        coordinator.pop()
    }

    func historyDescription() -> LocalizedStringResource {
        conclusionsCount == 0 ? .settingsHistoryEmptyDescription : .settingsHistoryDescription(count: conclusionsCount)
    }

    func onTapHistory() {
        analytics.buttonTapped(
            .settingsHistory,
            parameters: AnalyticsParameters([
                .itemCount: .int(conclusionsCount),
            ])
        )
        coordinator.screen(.history)
    }

    func onTapTemplates() {
        analytics.buttonTapped(.settingsTemplates)
        coordinator.screen(.templateList)
    }

    func onTapUserSettings() {
        analytics.buttonTapped(.settingsUserSettings)
        coordinator.screen(.userSettings)
    }

    func onTapSubscription() {
        analytics.buttonTapped(
            .settingsSubscription,
            parameters: AnalyticsParameters([
                .subscriptionType: .string(subscription.status?.type.rawValue ?? "none"),
            ])
        )
        coordinator.screen(.subscription)
    }

    func onTapNeuralModelSelection() {
        analytics.buttonTapped(
            .settingsNeuralModelSelection,
            parameters: AnalyticsParameters([
                .modelId: .string(neuralModel.id),
            ])
        )
        coordinator.sheet(
            .selectNeuralModel,
            arguments: SelectNeuralModelArguments(
                currentValue: neuralModel,
                onSelected: { [weak self] model in
                    guard let self = self else { return }
                    guard self.neuralModel != model else { return }

                    self.neuralModel = model
                    self.onNeuralModelSelected(model)
                }
            )
        )
    }

    func onTapNeuralModelSettings() {
        analytics.buttonTapped(.settingsNeuralModelSettings)
        coordinator.run(.neuralModelSettings) {
            self.coordinator.screen(.neuralModelSettings)
        }
    }

    func onTapStorage() {
        analytics.buttonTapped(.settingsStorage)
        coordinator.screen(.storage)
    }

    func onTapPrivacyPolicy() {
        analytics.buttonTapped(.settingsPrivacyPolicy)
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: .privacyPolicyTitle
            )
        )
    }

    func onTapTermsAndConditions() {
        analytics.buttonTapped(.settingsTermsAndConditions)
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: .termsAndConditionsTitle
            )
        )
    }

    func onTapAboutApp() {
        analytics.buttonTapped(.settingsAbout)
        coordinator.sheet(.about)
    }
}
