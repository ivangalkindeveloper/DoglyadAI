import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateEditViewModel: DViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case name
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
            subscription: subscription,
            analyticsDestination: .screen(.templateEdit)
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
            self.nameController.setText(template.name)
            self.templateController.setText(template.content)
        }
    }

    @Published var focus: Focus?
    @Published var usExaminationType: USExaminationType
    @NestedObservableObject var nameController = DTextFieldController(isRequired: true)
    @NestedObservableObject var templateController = DTextFieldController(isRequired: true)

    var focusList: [DTextFieldFocusValidationItem<Focus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .name,
                controller: nameController
            ),
            DTextFieldFocusValidationItem(
                focus: .content,
                controller: templateController
            ),
        ]
    }

    func onTapBack() {
        analytics.buttonTapped(.templateEditBack)
        coordinator.pop()
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(.templateEditSubmit)
        switch focus {
        case .name:
            focus = .content
        case .content, .none:
            focus = nil
        }
    }

    var canFocusPreviousField: Bool {
        switch focus {
        case .name, .none:
            false
        case .content:
            true
        }
    }

    var canFocusNextField: Bool {
        switch focus {
        case .name:
            true
        case .content, .none:
            false
        }
    }

    func onTapToolbarUp() {
        switch focus {
        case .name, .none:
            break
        case .content:
            focus = .name
        }
    }

    func onTapToolbarDown() {
        switch focus {
        case .name:
            focus = .content
        case .content, .none:
            break
        }
    }

    func onTapExaminationType() {
        analytics.buttonTapped(.templateEditExaminationType)
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
        analytics.buttonTapped(.templateEditSave)
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        guard let name = nameController.value,
              let content = templateController.value
        else {
            return
        }

        unfocus()

        let template = USExaminationTemplate(
            id: arguments.templateId,
            usExaminationType: usExaminationType,
            name: name,
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
        analytics.buttonTapped(.templateEditDelete)
        onDeleteTemplate(arguments.templateId)
        messager.show(
            type: .success,
            title: .templateDeletedSuccessTitle,
            description: .templateDeletedSuccessDescription
        )
        coordinator.pop()
    }
}
