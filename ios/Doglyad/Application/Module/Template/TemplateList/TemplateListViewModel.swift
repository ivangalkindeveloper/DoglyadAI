import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class TemplateListViewModel: DViewModel {
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
        analytics.buttonTapped(.templateListBack)
        coordinator.pop()
    }

    func onTapAdd() {
        analytics.buttonTapped(.templateListAdd)
        coordinator.screen(.templateAdd)
    }

    func onTapTemplate(
        _ template: USExaminationTemplate
    ) {
        analytics.buttonTapped(.templateListTemplate)
        coordinator.screen(
            .templateEdit,
            arguments: TemplateEditScreenArguments(
                templateId: template.id
            )
        )
    }
}
