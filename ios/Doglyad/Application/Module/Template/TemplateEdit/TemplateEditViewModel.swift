import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateEditViewModel: DViewModel {
    enum Focus: Hashable {
        case content
    }

    private let messager: DMessager
    private let arguments: TemplateEditScreenArguments
    private let onSaveTemplate: (USExaminationTemplate) -> Void
    private let onDeleteTemplate: (UUID) -> Void

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        messager: DMessager,
        arguments: TemplateEditScreenArguments,
        onSaveTemplate: @escaping (USExaminationTemplate) -> Void,
        onDeleteTemplate: @escaping (UUID) -> Void
    ) {
        self.messager = messager
        self.arguments = arguments
        self.onSaveTemplate = onSaveTemplate
        self.onDeleteTemplate = onDeleteTemplate
        usExaminationType = container.usExaminationTypeDefault
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    override func onInit() {
        handle {
            await self.container.templateRepository.getTemplate(
                id: self.arguments.templateId,
                usExaminationTypesById: self.container.usExaminationTypesById
            )!
        } onMainSuccess: { template in
            self.usExaminationType = self.container.usExaminationTypesById[template.usExaminationType.id]
                ?? self.container.usExaminationTypeDefault
            self.templateController.text = template.content
        }
    }

    @Published var focus: Focus?
    @Published var usExaminationType: USExaminationType
    @NestedObservableObject var templateController = DTextFieldController()

    func onTapBack() {
        coordinator.pop()
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        switch focus {
        case .content, .none:
            focus = nil
        }
    }

    func onTapExaminationType() {
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
        let isContentValid = templateController.validate()
        guard isContentValid else {
            templateController.showError(
                text: String(localized: .templateAddEmptyContentError)
            )
            return
        }

        unfocus()

        let content = templateController.text
        let template = USExaminationTemplate(
            id: arguments.templateId,
            usExaminationType: usExaminationType,
            content: content
        )
        onSaveTemplate(template)
        messager.show(
            type: .success,
            title: .templateSavedSuccessTitle,
            description: .templateSavedSuccessDescription
        )
        coordinator.pop()
    }

    func onTapDelete() {
        onDeleteTemplate(arguments.templateId)
        messager.show(
            type: .success,
            title: .templateDeletedSuccessTitle,
            description: .templateDeletedSuccessDescription
        )
        coordinator.pop()
    }
}
