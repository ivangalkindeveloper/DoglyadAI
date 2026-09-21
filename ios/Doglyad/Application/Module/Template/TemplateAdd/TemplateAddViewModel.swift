import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateAddViewModel: DViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case name
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
        if let selectedTypeId = container.ultrasoundReportRepository.getSelectedExaminationTypeId(),
           let selectedType = container.usExaminationTypesById[selectedTypeId]
        {
            usExaminationType = selectedType
        } else {
            usExaminationType = container.usExaminationTypeDefault
        }
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.templateAdd)
        )
    }

    @Published private(set) var isLoading = false
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
        analytics.buttonTapped(.templateAddBack)
        coordinator.pop()
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(.templateAddSubmit)
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

    func onTapReadyMadeTemplates() {
        analytics.buttonTapped(.templateAddReadyMadeTemplates)
        unfocus()
        coordinator.screen(
            .readyMadeTemplateList,
            arguments: ReadyMadeTemplateListScreenArguments(
                onTemplateSelected: { [weak self] template in
                    self?.onReadyMadeTemplateSelected(template)
                }
            )
        )
    }

    func onTapSave() {
        guard !isLoading else { return }

        analytics.buttonTapped(.templateAddSave)
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
            usExaminationType: usExaminationType,
            name: name,
            content: content
        )
        isLoading = true
        onSaveTemplate(template)
        messager.show(
            type: .success,
            title: .templateSavedSuccessTitle,
            description: .templateSavedSuccessDescription
        )
        coordinator.pop()
    }

    private func onReadyMadeTemplateSelected(
        _ template: USExaminationReadyMadeTemplate
    ) {
        guard let examinationType = container.getUSExaminationTypeById(id: template.examinationType) else { return }

        usExaminationType = examinationType
        nameController.setText(
            String(localized: template.getLocalizedTitle(for: Locale.current))
        )
        templateController.setText(
            template.getLocalizedContent(for: Locale.current)
        )
    }
}
