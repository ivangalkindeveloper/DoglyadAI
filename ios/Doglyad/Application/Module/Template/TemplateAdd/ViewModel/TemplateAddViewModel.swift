import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateAddViewModel: DModuleViewModel<any TemplateAddStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: TemplateAddFocus?
    @Published var usExaminationType: USExaminationType
    @NestedObservableObject var nameTextController: DTextFieldController
    @NestedObservableObject var templateTextController: DTextFieldController
    let templateId = UUID()
    private let messager: DMessager
    private let onSaveTemplate: (USExaminationTemplate) async throws -> Void
    private var initializationTask: Task<Void, Never>?
    private var initializationReadID: UUID?

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        messager: DMessager,
        onSaveTemplate: @escaping (USExaminationTemplate) async throws -> Void,
    ) {
        usExaminationType = container.usExaminationTypeDefault

        _nameTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                isRequired: true,
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.templateAdd.nameMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.templateAdd.nameMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.templateAdd.nameMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        _templateTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                isRequired: true,
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.templateAdd.contentMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.templateAdd.contentMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.templateAdd.contentMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        self.messager = messager
        self.onSaveTemplate = onSaveTemplate

        super.init(
            state: TemplateAddInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .templateAdd,
            ),
        )
        _ = nameTextController
        _ = templateTextController
    }

    var focusList: [DTextFieldFocusValidationItem<TemplateAddFocus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .name,
                inputTextController: nameTextController,
            ),
            DTextFieldFocusValidationItem(
                focus: .content,
                inputTextController: templateTextController,
            ),
        ]
    }

    var isPreviousFieldFocusable: Bool {
        switch focus {
        case .name, .none:
            false
        case .content:
            true
        }
    }

    var isNextFieldFocusable: Bool {
        switch focus {
        case .name:
            true
        case .content, .none:
            false
        }
    }

    override func onInit() {
        initializationTask?.cancel()
        let readID = UUID()
        initializationReadID = readID
        let initialTypeID = usExaminationType.id
        initializationTask = handle {
            try await self.container.ultrasoundReportRepository.getSelectedExaminationTypeId()
        } onMainSuccess: { id in
            guard !Task.isCancelled, self.initializationReadID == readID else {
                return
            }
            self.initializationReadID = nil
            if self.usExaminationType.id == initialTypeID, let id, let type = self.container.usExaminationTypesById[
                id,
            ] {
                self.usExaminationType = type
            }
        } onMainUnknownError: { _ in
            guard !Task.isCancelled, self.initializationReadID == readID else {
                return
            }
            self.initializationReadID = nil
        }
    }

    override func onDisappear() {
        super.onDisappear()
        initializationTask?.cancel()
        initializationReadID = nil
    }

    func onTapBack() {
        analytics.buttonTapped(
            .templateAddBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: TemplateAddFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .templateAddSubmit,
        )
        switch focus {
        case .name:
            focus = .content
        case .content, .none:
            focus = nil
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
        analytics.buttonTapped(
            .templateAddExaminationType,
        )
        coordinator.sheet(
            .selectUSExaminationType,
            arguments: SelectUSExaminationTypeArguments(
                currentValue: usExaminationType,
                onSelected: { [weak self] type in
                    withAnimation(
                        DTheme.light.animation,
                    ) {
                        self?.usExaminationType = type
                    }
                },
            ),
        )
    }

    func onTapReadyMadeTemplates() {
        analytics.buttonTapped(
            .templateAddReadyMadeTemplates,
        )
        unfocus()
        coordinator.screen(
            .readyMadeTemplateList,
            arguments: ReadyMadeTemplateListArguments(
                onTemplateSelected: { [weak self] template in
                    self?.onReadyMadeTemplateSelected(
                        template,
                    )
                },
            ),
        )
    }

    func onTapSave() {
        initializationTask?.cancel()
        initializationReadID = nil
        analytics.buttonTapped(
            .templateAddSave,
        )
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        guard let name = nameTextController.value,
              let content = templateTextController.value
        else {
            return
        }

        unfocus()

        let template = USExaminationTemplate(
            id: templateId,
            usExaminationType: usExaminationType,
            name: name,
            content: content,
        )

        performLocalOperation {
            try await self.onSaveTemplate(
                template,
            )
        } onSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .templateSavedSuccessTitle,
                ],
                description: self.container.l10n[
                    .templateSavedSuccessDescription,
                ],
            )
            if self.nameTextController.value == template.name,
               self.templateTextController.value == template.content,
               self.usExaminationType == template.usExaminationType
            {
                self.coordinator.pop()
            }
        } onFailure: { error in
            self.emit(
                TemplateAddErrorState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    private func onReadyMadeTemplateSelected(
        _ template: USExaminationReadyMadeTemplate,
    ) {
        guard let examinationType = container.getUSExaminationTypeById(
            id: template.examinationType,
        ) else {
            return
        }

        usExaminationType = examinationType
        nameTextController.restoreText(
            String(
                localized: template.localizedTitle,
            ),
        )
        templateTextController.restoreText(
            template.content,
        )
    }
}
