import DoglyadUI
import Foundation
import NestedObservableObject
import Router
import SwiftUI

@MainActor
final class UserSettingsViewModel: DViewModel {
    enum Focus: Hashable {
        case email
    }

    private let messager: DMessager
    private let onSaved: (String?, Bool) -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        initialEmail: String?,
        initialIncludeRecommendations: Bool,
        onSaved: @escaping (String?, Bool) -> Void
    ) {
        self.messager = messager
        self.onSaved = onSaved
        includeRecommendations = initialIncludeRecommendations
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.userSettings)
        )
        emailController.setText(initialEmail ?? "")
    }

    @Published var focus: Focus?
    @Published var includeRecommendations: Bool
    @NestedObservableObject var emailController = DTextFieldController(
        formatters: [
            DTextFieldEmailFormatter(),
            DTextFieldMaxLengthFormatter(maxLength: 254),
        ],
        validators: [
            DTextFieldEmailValidator(
                invalidValueErrorText: String(localized: .errorInvalidEmail)
            ),
        ]
    )

    func toggleIncludeRecommendations() {
        includeRecommendations.toggle()
    }

    func onTapBack() {
        analytics.buttonTapped(.userSettingsBack)
        coordinator.pop()
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        analytics.buttonTapped(.userSettingsSubmit)
        switch focus {
        case .email, .none:
            focus = nil
        }
    }

    func onTapSave() {
        let email = emailController.value
        analytics.buttonTapped(
            .userSettingsSave,
            parameters: AnalyticsParameters([
                .hasCurrentValue: .bool(email != nil),
            ])
        )
        guard emailController.validate() else { return }

        unfocus()

        onSaved(email, includeRecommendations)
        messager.show(
            type: .success,
            title: .userSettingsSavedSuccessMessageTitle,
            description: .userSettingsSavedSuccessMessageDescription
        )
        coordinator.pop()
    }
}
