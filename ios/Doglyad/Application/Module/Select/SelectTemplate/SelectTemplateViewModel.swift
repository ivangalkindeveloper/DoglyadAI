import Foundation

@MainActor
final class SelectTemplateViewModel: DViewModel {
    private let arguments: SelectTemplateArguments

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        arguments: SelectTemplateArguments
    ) {
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.selectTemplate),
            analyticsParameters: AnalyticsParameters([
                .hasCurrentValue: .bool(arguments.currentValue != nil),
            ])
        )
    }

    @Published var templates: [USExaminationTemplate] = []

    override func onInit() {
        let usExaminationId = arguments.usExaminationId
        handle {
            let templates = await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById
            )
            guard let usExaminationId else { return templates }
            return templates.filter { $0.usExaminationType.id == usExaminationId }
        } onMainSuccess: { templates in
            self.templates = templates
        }
    }

    func isSelected(
        _ template: USExaminationTemplate
    ) -> Bool {
        arguments.currentValue?.id == template.id
    }

    func onTemplateTap(
        _ template: USExaminationTemplate
    ) {
        analytics.buttonTapped(.selectTemplate)
        coordinator.dismissSheet()
        arguments.onSelected(template)
    }
}
