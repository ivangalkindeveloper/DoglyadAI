import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class TemplateListViewModel: DViewModel {
    @Published var templates: [USExaminationTemplate] = []
    @Published private(set) var isLoading = true

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.templateList)
        )
    }

    override func onInit() {
        loadTemplates()
    }

    private func loadTemplates() {
        isLoading = true
        handle {
            await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { templates in
            self.templates = templates
        }
    }

    func onTapBack() {
        analytics.buttonTapped(.templateListBack)
        coordinator.pop()
    }

    func onTapAdd() {
        analytics.buttonTapped(.templateListAdd)
        coordinator.screen(
            .templateAdd,
            arguments: TemplateAddScreenArguments(
                onTemplatesChanged: { [weak self] in
                    self?.loadTemplates()
                }
            )
        )
    }

    func onTapTemplate(
        _ template: USExaminationTemplate
    ) {
        analytics.buttonTapped(.templateListTemplate)
        coordinator.screen(
            .templateEdit,
            arguments: TemplateEditScreenArguments(
                templateId: template.id,
                onTemplatesChanged: { [weak self] in
                    self?.loadTemplates()
                }
            )
        )
    }
}
