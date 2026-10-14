import Combine
import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class UserSettingsViewModel: DModuleViewModel, DTextFieldFocusValidating {
    enum Focus: Hashable {
        case email
    }

    private let messager: DMessager
    private let onSaved: (String?, Bool, Bool, Bool) async throws -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        getInitialEmail: @escaping () -> String?,
        getInitialIsRecommendationsIncluded: @escaping () -> Bool,
        getInitialIsPhotoRemarks: @escaping () -> Bool,
        getInitialIsDescriptionRemarks: @escaping () -> Bool,
        onSaved: @escaping (String?, Bool, Bool, Bool) async throws -> Void,
    ) {
        self.messager = messager
        self.onSaved = onSaved
        isRecommendationsIncluded = getInitialIsRecommendationsIncluded()
        isPhotoRemarks = getInitialIsPhotoRemarks()
        isDescriptionRemarks = getInitialIsDescriptionRemarks()
        _emailController = NestedObservableObject(
            wrappedValue: DTextFieldController(
                formatters: [
                    DTextFieldEmailFormatter(),
                    DTextFieldMaxLengthFormatter(
                        maxLength: 254,
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
                ],
            ),
        )
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .userSettings,
            ),
        )
        emailController.setText(
            getInitialEmail() ?? "",
        )
    }

    @Published private(set) var isLoading = false
    @Published var focus: Focus?
    @Published var isRecommendationsIncluded: Bool
    @Published var isPhotoRemarks: Bool
    @Published var isDescriptionRemarks: Bool
    @NestedObservableObject var emailController: DTextFieldController

    var focusList: [DTextFieldFocusValidationItem<Focus>] {
        [
            DTextFieldFocusValidationItem(
                focus: .email,
                controller: emailController,
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
        _ newFocus: Focus?,
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

    func togglePhotoRemarks() { isPhotoRemarks.toggle() }

    func toggleDescriptionRemarks() { isDescriptionRemarks.toggle() }

    func onTapSave() {
        guard !isLoading else { return }

        let email = emailController.value
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

        isLoading = true
        handle {
            try await self.onSaved(
                email,
                self.isRecommendationsIncluded,
                self.isPhotoRemarks,
                self.isDescriptionRemarks,
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .userSettingsSavedSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .userSettingsSavedSuccessMessageDescription,
                ],
            )
            self.coordinator.pop()
        } onMainUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
