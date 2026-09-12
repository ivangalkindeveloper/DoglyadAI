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
    private let onSaved: (String, Bool) -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        initialEmail: String?,
        initialIncludeRecommendations: Bool,
        onSaved: @escaping (String, Bool) -> Void
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
        emailController.text = initialEmail ?? ""
    }

    @Published var focus: Focus?
    @Published var includeRecommendations: Bool
    @NestedObservableObject var emailController = DTextFieldController()

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
        analytics.buttonTapped(
            .userSettingsSave,
            parameters: AnalyticsParameters([
                .hasCurrentValue: .bool(!emailController.text.isEmpty),
            ])
        )
        unfocus()

        let email = emailController.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSaved(email, includeRecommendations)
        messager.show(
            type: .success,
            title: .userSettingsSavedSuccessMessageTitle,
            description: .userSettingsSavedSuccessMessageDescription
        )
        coordinator.pop()
    }
}
