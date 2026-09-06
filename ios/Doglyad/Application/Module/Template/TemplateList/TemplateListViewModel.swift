import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class TemplateListViewModel: DViewModel {
    override init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel
    ) {
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    override func onInit() {
        handle {
            await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById
            )
        } onMainSuccess: { templates in
            self.templates = templates
        }
    }

    @Published var templates: [USExaminationTemplate] = []

    func onTapBack() {
        coordinator.pop()
    }

    func onTapAdd() {
        coordinator.screen(.templateAdd)
    }

    func onTapTemplate(
        _ template: USExaminationTemplate
    ) {
        coordinator.screen(
            .templateEdit,
            arguments: TemplateEditScreenArguments(
                templateId: template.id
            )
        )
    }
}
