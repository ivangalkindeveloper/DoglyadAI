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
    private let onEmailSaved: (String) -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        subscription: SubscriptionViewModel,
        initialEmail: String?,
        onEmailSaved: @escaping (String) -> Void
    ) {
        self.messager = messager
        self.onEmailSaved = onEmailSaved
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
        emailController.text = initialEmail ?? ""
    }

    @Published var focus: Focus?
    @NestedObservableObject var emailController = DTextFieldController()

    func onTapBack() {
        coordinator.pop()
    }

    func unfocus() {
        focus = nil
    }

    func onSubmit() {
        switch focus {
        case .email, .none:
            focus = nil
        }
    }

    func onTapSave() {
        unfocus()

        let email = emailController.text.trimmingCharacters(in: .whitespacesAndNewlines)
        onEmailSaved(email)
        messager.show(
            type: .success,
            title: .userSettingsSavedSuccessMessageTitle,
            description: .userSettingsSavedSuccessMessageDescription
        )
        coordinator.pop()
    }
}
