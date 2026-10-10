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
        userEmail: String?,
    ) {
        self.messager = messager
        self.arguments = arguments
        self.userEmail = userEmail
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(
                .share,
            ),
        )
    }

    @Published var isLoading = false

    var isUserEmailAvailable: Bool {
        userEmail != nil
    }

    var isUserEmailButtonVisible: Bool {
        switch subscription.availability(
            of: .sendingReportByEmail,
        ) {
        case .offered, .available:
            true
        case .unavailable:
            false
        }
    }

    var userEmailButtonTitle: String {
        container.l10n.text(
            .shareUserEmailTitle,
            values: ["prefix": container.l10n.text(
                .buttonShareUserEmailPrefix,
            ), "email": userEmail ?? ""],
        )
    }

    var subject: String {
        arguments.report.shareSubject(
            examinationTypesById: container.usExaminationTypesById,
            l10n: container.l10n,
        )
    }

    var shareMessage: String {
        arguments.report.shareMessage(
            l10n: container.l10n,
        )
    }

    func onTapUserEmail() {
        analytics.buttonTapped(
            .shareUserEmail,
            parameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        userEmail != nil,
                    ),
                ],
            ),
        )
        guard let userEmail else { return }
        coordinator.run(
            .sendingReportByEmail,
            dismissesSheetOnPaywall: true,
        ) {
            self.sendReportEmail(
                to: userEmail,
            )
        }
    }

    private func sendReportEmail(
        to userEmail: String,
    ) {
        let ultrasoundConfig = container.applicationConfig.ultrasound
        handle {
            self.isLoading = true
            try await self.container.userSettingsRepository.sendEmail(
                email: self.arguments.report.makeEmail(
                    recipientEmail: userEmail,
                    examinationTypesById: self.container.usExaminationTypesById,
                    scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                        resizeMaxDimension: ultrasoundConfig.scanPhotoResizeMaxDimension,
                        compressionQuality: ultrasoundConfig.scanPhotoCompressionQuality,
                    ),
                    l10n: self.container.l10n,
                ),
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
            self.coordinator.dismissSheet()
            self.messager.show(
                type: .success,
                title: self.container.l10n[
                    .shareUserEmailSuccessMessageTitle,
                ],
                description: self.container.l10n[
                    .shareUserEmailSuccessMessageDescription,
                ],
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    func onTapEmail() {
        analytics.buttonTapped(
            .shareCustomEmail,
        )
        coordinator.run(
            .sendingReportByEmail,
            dismissesSheetOnPaywall: true,
        ) {
            self.coordinator.dismissSheet()
            UIApplication.openMail(
                subject: self.subject,
                body: self.shareMessage,
            )
        }
    }

    func onTapCopy() {
        analytics.buttonTapped(
            .shareCopy,
        )
        coordinator.dismissSheet()
        UIApplication.pasteboard(
            shareMessage,
        )
        messager.show(
            type: .success,
            title: container.l10n[
                .shareExaminationCopyMessageTitle,
            ],
            description: container.l10n[
                .shareExaminationCopyMessageDescription,
            ],
        )
    }
}
