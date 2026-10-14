import Combine
import DoglyadUI
import Foundation

@MainActor
final class SelectTemplateViewModel: DModuleViewModel {
    private let messager: DMessager?
    private let arguments: SelectTemplateArguments

    init(
        container: DependencyContainer,
        messager: DMessager? = nil,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        arguments: SelectTemplateArguments,
    ) {
        self.messager = messager
        self.arguments = arguments
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .selectTemplate,
            ),
            analyticsParameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        arguments.currentValue != nil,
                    ),
                ],
            ),
        )
    }

    @Published var templates: [USExaminationTemplate] = []

    override func onInit() {
        let usExaminationId = arguments.usExaminationId
        handle {
            let templates = try await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
            guard let usExaminationId else { return templates }
            return templates.filter { $0.usExaminationType.id == usExaminationId }
        } onMainSuccess: { templates in
            self.templates = templates
        } onMainUnknownError: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func isSelected(
        _ template: USExaminationTemplate,
    ) -> Bool {
        arguments.currentValue?.id == template.id
    }

    func onTemplateTap(
        _ template: USExaminationTemplate,
    ) {
        analytics.buttonTapped(
            .selectTemplate,
        )
        handle { try await self.arguments.onSelected(
            template,
        ) }
        onMainSuccess: { _ in self.coordinator.dismissSheet() } onMainUnknownError: { _ in
            self.messager?.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
