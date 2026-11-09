import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class TemplateEditViewModel: DModuleViewModel<any TemplateEditStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: TemplateEditFocus?
    @Published var usExaminationType: USExaminationType
    @NestedObservableObject var nameTextController: DTextFieldController
    @NestedObservableObject var templateTextController: DTextFieldController
    private var initializationFailureValues: (name: String, content: String, typeID: String)?
    private let messager: DMessager
    private let arguments: TemplateEditArguments
    private let onSaveTemplate: (USExaminationTemplate) async throws -> Void
    private let onDeleteTemplate: (UUID) async throws -> Void
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
        arguments: TemplateEditArguments,
        onSaveTemplate: @escaping (USExaminationTemplate) async throws -> Void,
        onDeleteTemplate: @escaping (UUID) async throws -> Void,
    ) {
        usExaminationType = container.usExaminationTypeDefault

        _nameTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                isRequired: true,
                formatters: [
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.templateEdit.nameMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.templateEdit.nameMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.templateEdit.nameMaxLength,
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
                        maxLength: container.applicationConfig.templateEdit.contentMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.templateEdit.contentMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.templateEdit.contentMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        self.messager = messager
        self.arguments = arguments
        self.onSaveTemplate = onSaveTemplate
        self.onDeleteTemplate = onDeleteTemplate

        super.init(
            state: TemplateEditInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .templateEdit,
            ),
        )
        _ = nameTextController
        _ = templateTextController
    }

    var focusList: [DTextFieldFocusValidationItem<TemplateEditFocus>] {
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
        let previousFailure = initializationFailureValues
        let editedName = nameTextController.text
        let editedContent = templateTextController.text
        let editedType = usExaminationType

        initializationTask = handle {
            try await self.container.templateRepository.getTemplate(
                id: self.arguments.templateId,
                usExaminationTypesById: self.container.usExaminationTypesById,
            )
        } onMainSuccess: { template in
            guard !Task.isCancelled, self.initializationReadID == readID else {
                return
            }
            self.initializationReadID = nil
            guard let template else {
                self.rememberInitializationFailure()
                self.emit(
                    TemplateEditInitializationErrorState(
                        error: CocoaError(
                            .fileReadNoSuchFile,
                        ),
                    ),
                )
                self.messager.showUnknownError(
                    l10n: self.container.l10n,
                )
                return
            }
            if self.usExaminationType == editedType, previousFailure?.typeID == nil || previousFailure?.typeID == editedType.id {
                self.usExaminationType = self.container.usExaminationTypesById[
                    template.usExaminationType.id,
                ] ?? self.container.usExaminationTypeDefault
            }
            if self.nameTextController.text == editedName, previousFailure?.name == nil || previousFailure?.name == editedName {
                self.nameTextController.restoreText(
                    template.name,
                )
            }
            if self.templateTextController.text == editedContent, previousFailure?.content == nil || previousFailure?.content == editedContent {
                self.templateTextController.restoreText(
                    template.content,
                )
            }
            self.initializationFailureValues = nil
            self.emit(
                TemplateEditInitialState(),
            )
        } onMainUnknownError: { error in
            guard !Task.isCancelled, self.initializationReadID == readID else {
                return
            }
            self.initializationReadID = nil
            self.rememberInitializationFailure()
            self.emit(
                TemplateEditInitializationErrorState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    override func onDisappear() {
        super.onDisappear()
        initializationTask?.cancel()
        initializationReadID = nil
    }

    func onTapRetryInitialization() {
        onInit()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .templateEditBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: TemplateEditFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .templateEditSubmit,
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
            .templateEditExaminationType,
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

    func onTapSave() {
        guard initializationReadID == nil else {
            return
        }
        switch state {
        case _ as TemplateEditInitializationErrorState: return;
        default: break
        }
        analytics.buttonTapped(
            .templateEditSave,
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
            id: arguments.templateId,
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
                TemplateEditErrorState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapDelete() {
        switch state {
        case _ as TemplateEditInitializationErrorState: return
        default: break
        }

        analytics.buttonTapped(
            .templateEditDelete,
        )
        coordinator.sheet(
            .templateDelete,
            arguments: TemplateDeleteArguments(
                onConfirm: { [weak self] in
                    self?.deleteTemplate()
                },
            ),
        )
    }

    private func deleteTemplate() {
        switch state {
        case _ as TemplateEditInitializationErrorState: return
        default: break
        }

        unfocus()

        performLocalOperation {
            try await self.onDeleteTemplate(
                self.arguments.templateId,
            )
        } onSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .templateDeletedSuccessTitle,
                ],
                description: self.container.l10n[
                    .templateDeletedSuccessDescription,
                ],
            )
            self.coordinator.pop()
        } onFailure: { error in
            self.emit(
                TemplateEditErrorState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    private func rememberInitializationFailure() {
        if initializationFailureValues == nil {
            initializationFailureValues = (nameTextController.text, templateTextController.text, usExaminationType.id)
        }
    }
}
