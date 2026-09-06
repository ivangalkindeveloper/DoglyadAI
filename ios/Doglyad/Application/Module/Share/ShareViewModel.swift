import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import UIKit

@MainActor
final class ShareViewModel: DViewModel {
    private let messager: DMessager
    private let arguments: ShareArguments
    let userEmail: String?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: ShareArguments,
        subscription: SubscriptionViewModel,
        userEmail: String?
    ) {
        self.messager = messager
        self.arguments = arguments
        self.userEmail = userEmail
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    @Published var isLoading = false

    var isUserEmailAvailable: Bool {
        userEmail != nil
    }

    var isUserEmailButtonVisible: Bool {
        switch subscription.availability(of: .sendingConclusionByEmail) {
        case .offered, .available:
            return true
        case .unavailable:
            return false
        }
    }

    var userEmailButtonTitle: String {
        "\(String(localized: .buttonShareUserEmailPrefix)) \(userEmail ?? "")"
    }

    var subject: String {
        arguments.conclusion.shareSubject(
            examinationTypesById: container.usExaminationTypesById
        )
    }

    var shareMessage: String {
        arguments.conclusion.shareMessage
    }

    func onTapUserEmail() {
        guard let userEmail = userEmail else { return }
        coordinator.run(.sendingConclusionByEmail, dismissesSheetOnPaywall: true) {
            self.sendConclusionEmail(to: userEmail)
        }
    }

    private func sendConclusionEmail(to userEmail: String) {
        handle {
            self.isLoading = true
            try await self.container.userSettingsRepository.sendEmail(
                email: USExaminationEmail(
                    recipientEmail: userEmail,
                    subject: self.subject,
                    body: self.shareMessage
                )
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
            self.coordinator.dismissSheet()
            self.messager.show(
                type: .success,
                title: .shareUserEmailSuccessMessageTitle,
                description: .shareUserEmailSuccessMessageDescription
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }

    func onTapEmail() {
        coordinator.run(.sendingConclusionByEmail, dismissesSheetOnPaywall: true) {
            self.coordinator.dismissSheet()
            UIApplication.openMail(
                subject: self.subject,
                body: self.shareMessage
            )
        }
    }

    func onTapCopy() {
        coordinator.dismissSheet()
        UIApplication.pasteboard(shareMessage)
        messager.show(
            type: .success,
            title: .shareExaminationCopyMessageTitle,
            description: .shareExaminationCopyMessageDescription
        )
    }
}
