import DoglyadNetwork
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class SettingsViewModel: DViewModel {
    private let container: DependencyContainer
    private let router: DRouter
    private let onNeuralModelSelected: (USExaminationNeuralModel) -> Void
    @NestedObservableObject private var subscription: SubscriptionViewModel

    init(
        container: DependencyContainer,
        router: DRouter,
        initialNeuralModel: USExaminationNeuralModel,
        subscription: SubscriptionViewModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.container = container
        self.router = router
        _subscription = NestedObservableObject(wrappedValue: subscription)
        self.onNeuralModelSelected = onNeuralModelSelected
        neuralModel = initialNeuralModel
        super.init()
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
        router.pop()
    }

    func historyDescription() -> LocalizedStringResource {
        conclusionsCount == 0 ? .settingsHistoryEmptyDescription : .settingsHistoryDescription(count: conclusionsCount)
    }

    func onTapHistory() {
        router.push(
            route: RouteScreen(
                type: .history
            )
        )
    }

    func onTapTemplates() {
        router.push(
            route: RouteScreen(
                type: .templateList
            )
        )
    }

    func onTapUserSettings() {
        router.push(
            route: RouteScreen(
                type: .userSettings
            )
        )
    }

    func onTapSubscription() {
        router.push(
            route: RouteScreen(
                type: .subscription
            )
        )
    }

    func onTapNeuralModelSelection() {
        router.push(
            route: RouteSheet(
                type: .selectNeuralModel,
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
        )
    }

    func onTapNeuralModelSettings() {
        subscription.run(
            .neuralModelSettings,
            router: router
        ) {
            self.router.push(
                route: RouteScreen(
                    type: .neuralModelSettings
                )
            )
        }
    }

    func onTapStorage() {
        router.push(
            route: RouteScreen(
                type: .storage
            )
        )
    }

    func onTapPrivacyPolicy() {
        router.push(
            route: RouteSheet(
                type: .webDocument,
                arguments: WebDocumentBottomSheetArguments(
                    url: container.applicationConfig.privacyPolicyUrl,
                    title: .privacyPolicyTitle
                )
            )
        )
    }

    func onTapTermsAndConditions() {
        router.push(
            route: RouteSheet(
                type: .webDocument,
                arguments: WebDocumentBottomSheetArguments(
                    url: container.applicationConfig.termsAndConditionsUrl,
                    title: .termsAndConditionsTitle
                )
            )
        )
    }

    func onTapAboutApp() {
        router.push(
            route: RouteSheet(
                type: .about
            )
        )
    }
}
