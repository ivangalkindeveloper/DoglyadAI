import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI
import UIKit

@MainActor
final class RecievedConclusionViewModel: DViewModel {
    private let messager: DMessager
    private let arguments: RecievedConclusionBottomSheetArguments
    let userEmail: String?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: RecievedConclusionBottomSheetArguments,
        subscription: SubscriptionViewModel,
        userEmail: String?
    ) {
        self.messager = messager
        self.arguments = arguments
        self.userEmail = userEmail
        markdownViewModel = RecievedConclusionMarkdownViewModel(
            response: arguments.conclusion.actualModelConclusion.response
        )
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    @Published var isLoading = false
    // A plain reference keeps per-word updates scoped to RecievedConclusionMarkdownView.
    let markdownViewModel: RecievedConclusionMarkdownViewModel

    var model: USExaminationModelConclusion {
        arguments.conclusion.actualModelConclusion
    }

    var response: String {
        arguments.conclusion.actualModelConclusion.response
    }

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

    var userEmailButtonTitle: LocalizedStringResource {
        "\(String(localized: .buttonShareUserEmailPrefix)) \(userEmail ?? "")"
    }

    var userEmailButtonBadge: DButtonBadge? {
        switch subscription.availability(of: .sendingConclusionByEmail) {
        case .offered:
            return DButtonBadge(
                .entitlementPro,
                isShimmering: true
            )
        case .available, .unavailable:
            return nil
        }
    }

    func onTapConclusion() {
        coordinator.dismissSheet()
        coordinator.screen(
            .conclusion,
            arguments: ConclusionScreenArguments(
                conclusion: arguments.conclusion
            )
        )
    }

    func onTapUserEmail() {
        guard let userEmail: String = userEmail else { return }
        coordinator.run(
            .sendingConclusionByEmail,
            dismissesSheetOnPaywall: true
        ) {
            self.sendConclusionEmail(to: userEmail)
        }
    }

    private func sendConclusionEmail(to userEmail: String) {
        let conclusion = arguments.conclusion
        let subject = conclusion.shareSubject(
            examinationTypesById: container.usExaminationTypesById
        )
        let shareMessage = conclusion.shareMessage
        handle {
            self.isLoading = true
            try await self.container.userSettingsRepository.sendEmail(
                email: USExaminationEmail(
                    recipientEmail: userEmail,
                    subject: subject,
                    body: shareMessage
                )
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
            self.messager.show(
                type: .success,
                title: .shareUserEmailSuccessMessageTitle,
                description: .shareUserEmailSuccessMessageDescription
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }

    func onTapCopy() {
        UIApplication.pasteboard(response)
        messager.show(
            type: .success,
            title: .conclusionModelCopyMessageTitle,
            description: .conclusionModelCopyMessageDescription
        )
    }
}
