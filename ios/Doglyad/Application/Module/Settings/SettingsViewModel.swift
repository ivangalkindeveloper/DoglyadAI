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
            subscription: subscription
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
        coordinator.pop()
    }

    func historyDescription() -> LocalizedStringResource {
        conclusionsCount == 0 ? .settingsHistoryEmptyDescription : .settingsHistoryDescription(count: conclusionsCount)
    }

    func onTapHistory() {
        coordinator.screen(.history)
    }

    func onTapTemplates() {
        coordinator.screen(.templateList)
    }

    func onTapUserSettings() {
        coordinator.screen(.userSettings)
    }

    func onTapSubscription() {
        coordinator.screen(.subscription)
    }

    func onTapNeuralModelSelection() {
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
        coordinator.run(.neuralModelSettings) {
            self.coordinator.screen(.neuralModelSettings)
        }
    }

    func onTapStorage() {
        coordinator.screen(.storage)
    }

    func onTapPrivacyPolicy() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.privacyPolicyUrl,
                title: .privacyPolicyTitle
            )
        )
    }

    func onTapTermsAndConditions() {
        coordinator.sheet(
            .webDocument,
            arguments: WebDocumentBottomSheetArguments(
                url: container.applicationConfig.termsAndConditionsUrl,
                title: .termsAndConditionsTitle
            )
        )
    }

    func onTapAboutApp() {
        coordinator.sheet(.about)
    }
}
