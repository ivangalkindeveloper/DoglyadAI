import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateAddViewModel: DViewModel {
    enum Focus: Hashable {
        case content
    }

    private let messager: DMessager
    private let onSaveTemplate: (USExaminationTemplate) -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        messager: DMessager,
        onSaveTemplate: @escaping (USExaminationTemplate) -> Void
    ) {
        self.messager = messager
        self.onSaveTemplate = onSaveTemplate
        usExaminationType = container.usExaminationTypeDefault
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.templateAdd)
        )
    }

    @Published var focus: Focus?
    @Published var usExaminationType: USExaminationType
    @NestedObservableObject var templateController = DTextFieldController()

    func onTapBack() {
        analytics.buttonTapped(.templateAddBack)
        coordinator.pop()
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(.templateAddSubmit)
        switch focus {
        case .content, .none:
            focus = nil
        }
    }

    func onTapExaminationType() {
        analytics.buttonTapped(.templateAddExaminationType)
        coordinator.sheet(
            .selectUSExaminationType,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: usExaminationType,
                onSelected: { [weak self] type in
                    self?.usExaminationType = type
                }
            )
        )
    }

    func onTapSave() {
        analytics.buttonTapped(.templateAddSave)
        let isContentValid = templateController.validate()
        guard isContentValid else {
            templateController.showError(
                text: String(localized: .templateAddEmptyContentError)
            )
            return
        }

        unfocus()

        let content = templateController.text
        let usExaminationType = usExaminationType

        handle {
            await self.container.templateRepository.getTemplates(
                usExaminationTypesById: self.container.usExaminationTypesById
            )
        } onMainSuccess: { templates in
            let hasTemplateForType = templates.contains { $0.usExaminationType.id == usExaminationType.id }
            guard !hasTemplateForType else {
                self.messager.show(
                    type: .error,
                    title: .templateAddDuplicateExaminationTypeTitle,
                    description: .templateAddDuplicateExaminationTypeDescription
                )
                return
            }

            let template = USExaminationTemplate(
                usExaminationType: usExaminationType,
                content: content
            )
            self.onSaveTemplate(template)
            self.messager.show(
                type: .success,
                title: .templateSavedSuccessTitle,
                description: .templateSavedSuccessDescription
            )
            self.coordinator.pop()
        }
    }
}
