import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI
import UIKit

@MainActor
final class RecievedConclusionViewModel: DViewModel {
    private let container: DependencyContainer
    private let messager: DMessager
    private let router: DRouter
    private let arguments: RecievedConclusionBottomSheetArguments
    @NestedObservableObject private var subscription: SubscriptionViewModel
    let userEmail: String?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: RecievedConclusionBottomSheetArguments,
        subscription: SubscriptionViewModel,
        userEmail: String?
    ) {
        self.container = container
        self.messager = messager
        self.router = router
        self.arguments = arguments
        _subscription = NestedObservableObject(wrappedValue: subscription)
        self.userEmail = userEmail
        markdownViewModel = RecievedConclusionMarkdownViewModel(
            response: arguments.conclusion.actualModelConclusion.response
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
        router.dismissSheet()
        router.push(
            route: RouteScreen(
                type: .conclusion,
                arguments: ConclusionScreenArguments(
                    conclusion: arguments.conclusion
                )
            )
        )
    }

    func onTapUserEmail() {
        guard let userEmail: String = userEmail else { return }
        subscription.run(
            .sendingConclusionByEmail,
            router: router,
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
