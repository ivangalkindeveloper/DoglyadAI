import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class UserSettingsViewModel: DModuleViewModel<any UserSettingsStateProtocol>, DTextFieldFocusValidatingProtocol {
    @Published var focus: UserSettingsFocus?
    @Published var isRecommendationsIncluded: Bool
    @Published var isPhotoRemarks: Bool
    @Published var isDescriptionRemarks: Bool
    @NestedObservableObject var emailTextController: DTextFieldController
    private let messager: DMessager
    private let onSaved: (String?, Bool, Bool, Bool) async throws -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        getInitialEmail: @escaping () -> String?,
        getInitialIsRecommendationsIncluded: @escaping () -> Bool,
        getInitialIsPhotoRemarks: @escaping () -> Bool,
        getInitialIsDescriptionRemarks: @escaping () -> Bool,
        onSaved: @escaping (String?, Bool, Bool, Bool) async throws -> Void,
    ) {
        isRecommendationsIncluded = getInitialIsRecommendationsIncluded()
        isPhotoRemarks = getInitialIsPhotoRemarks()
        isDescriptionRemarks = getInitialIsDescriptionRemarks()

        _emailTextController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldEmailFormatter(),
                    DTextFieldMaxLengthFormatter(
                        maxLength: container.applicationConfig.userSettings.emailMaxLength,
                    ),
                ],
                validators: [
                    DTextFieldEmailValidator(
                        invalidValueErrorText: String(
                            localized: container.l10n[
                                .errorInvalidEmailDescription,
                            ],
                        ),
                    ),
                    DTextFieldLengthValidator(
                        validRange: 0 ... container.applicationConfig.userSettings.emailMaxLength,
                        invalidValueErrorText: container.l10n.text(
                            .errorFieldLengthExceededDescription,
                            values: [.maxLength: String(
                                container.applicationConfig.userSettings.emailMaxLength,
                            )],
                        ),
                    ),
                ],
            ),
        )
        self.messager = messager
        self.onSaved = onSaved

        super.init(
            state: UserSettingsInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .userSettings,
            ),
        )
        _ = emailTextController
        emailTextController.restoreText(
            getInitialEmail() ?? "",
        )
    }

    var focusList: [DTextFieldFocusValidationItem<UserSettingsFocus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .email,
                inputTextController: emailTextController,
            ),
        ]
    }

    func onTapBack() {
        analytics.buttonTapped(
            .userSettingsBack,
        )
        coordinator.pop()
    }

    func onFocusChanged(
        _ newFocus: UserSettingsFocus?,
    ) {
        focus = newFocus
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(
            .userSettingsSubmit,
        )
        switch focus {
        case .email, .none:
            focus = nil
        }
    }

    func toggleRecommendationsIncluded() {
        isRecommendationsIncluded.toggle()
    }

    func togglePhotoRemarks() {
        isPhotoRemarks.toggle()
    }

    func toggleDescriptionRemarks() {
        isDescriptionRemarks.toggle()
    }

    func onTapSave() {
        let email = emailTextController.value
        analytics.buttonTapped(
            .userSettingsSave,
            parameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        email != nil,
                    ),
                ],
            ),
        )
        if let invalidFocus = firstInvalidFocus() {
            focus = invalidFocus
            return
        }

        unfocus()

        let isRecommendationsIncluded = isRecommendationsIncluded
        let isPhotoRemarks = isPhotoRemarks
        let isDescriptionRemarks = isDescriptionRemarks
        performLocalOperation {
            try await self.onSaved(
                email,
                isRecommendationsIncluded,
                isPhotoRemarks,
                isDescriptionRemarks,
            )
        } onSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .userSettingsSavedSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .userSettingsSavedSuccessMessageDescription,
                ],
            )
            if self.emailTextController.value == email,
               self.isRecommendationsIncluded == isRecommendationsIncluded,
               self.isPhotoRemarks == isPhotoRemarks,
               self.isDescriptionRemarks == isDescriptionRemarks
            {
                self.coordinator.pop()
            }
        } onFailure: { error in
            self.emit(
                UserSettingsErrorState(
                    error: error,
                ),
            )

            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
