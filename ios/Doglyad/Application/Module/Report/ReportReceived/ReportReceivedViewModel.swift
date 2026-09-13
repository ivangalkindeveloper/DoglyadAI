import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI
import UIKit

@MainActor
final class ReportReceivedViewModel: DViewModel {
    private let messager: DMessager
    private let arguments: ReportReceivedBottomSheetArguments
    let userEmail: String?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: ReportReceivedBottomSheetArguments,
        subscription: SubscriptionViewModel,
        userEmail: String?
    ) {
        self.messager = messager
        self.arguments = arguments
        self.userEmail = userEmail
        markdownViewModel = ReportReceivedMarkdownViewModel(
            response: arguments.report.actualModelReport.markdownText
        )
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .bottomSheet(.reportReceived)
        )
    }

    @Published var isLoading = false
    // A plain reference keeps per-word updates scoped to ReportReceivedMarkdownView.
    let markdownViewModel: ReportReceivedMarkdownViewModel

    var model: USExaminationModelReport {
        arguments.report.actualModelReport
    }

    var response: String {
        arguments.report.actualModelReport.plainText
    }

    var isUserEmailAvailable: Bool {
        userEmail != nil
    }

    var isUserEmailButtonVisible: Bool {
        switch subscription.availability(of: .sendingReportByEmail) {
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
        switch subscription.availability(of: .sendingReportByEmail) {
        case .offered:
            return DButtonBadge(
                .entitlementPro,
                isShimmering: true
            )
        case .available, .unavailable:
            return nil
        }
    }

    func onTapReport() {
        analytics.buttonTapped(.reportReceivedOpen)
        coordinator.dismissSheet()
        coordinator.screen(
            .reportDetail,
            arguments: ReportDetailScreenArguments(
                report: arguments.report
            )
        )
    }

    func onTapUserEmail() {
        analytics.buttonTapped(
            .reportReceivedEmail,
            parameters: AnalyticsParameters([
                .hasCurrentValue: .bool(userEmail != nil),
            ])
        )
        guard let userEmail: String = userEmail else { return }
        coordinator.run(
            .sendingReportByEmail,
            dismissesSheetOnPaywall: true
        ) {
            self.sendReportEmail(to: userEmail)
        }
    }

    private func sendReportEmail(to userEmail: String) {
        let report = arguments.report
        let ultrasoundConfig = container.applicationConfig.ultrasound
        handle {
            self.isLoading = true
            try await self.container.userSettingsRepository.sendEmail(
                email: report.makeEmail(
                    recipientEmail: userEmail,
                    examinationTypesById: self.container.usExaminationTypesById,
                    scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                        resizeMaxDimension: ultrasoundConfig.scanPhotoResizeMaxDimension,
                        compressionQuality: ultrasoundConfig.scanPhotoCompressionQuality
                    )
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
        analytics.buttonTapped(.reportReceivedCopy)
        UIApplication.pasteboard(response)
        messager.show(
            type: .success,
            title: .reportReceivedCopyMessageTitle,
            description: .reportReceivedCopyMessageDescription
        )
    }
}
