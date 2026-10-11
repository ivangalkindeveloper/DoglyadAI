import Combine
import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class TemplateListViewModel: DModuleViewModel {
    @Published var templates: [USExaminationTemplate] = []
    @Published private(set) var isLoading = true

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
    ) {
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .templateList,
            ),
        )
    }

    override func onInit() {
        loadTemplates()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .templateListBack,
        )
        coordinator.pop()
    }

    func onTapAdd() {
        analytics.buttonTapped(
            .templateListAdd,
        )
        coordinator.screen(
            .templateAdd,
            arguments: TemplateAddArguments(
                onTemplatesChanged: { [weak self] in
                    self?.loadTemplates()
                },
            ),
        )
    }

    func onTapTemplate(
        _ template: USExaminationTemplate,
    ) {
        analytics.buttonTapped(
            .templateListTemplate,
        )
        coordinator.screen(
            .templateEdit,
            arguments: TemplateEditArguments(
                templateId: template.id,
                onTemplatesChanged: { [weak self] in
                    self?.loadTemplates()
                },
            ),
        )
    }
}

private extension TemplateListViewModel {
    func loadTemplates() {
        isLoading = true
        handle {
            await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { templates in
            self.templates = templates
        }
    }
}
