import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI
import UIKit

@MainActor
final class ReportReceivedViewModel: DModuleViewModel {
    private let messager: DMessager
    private let arguments: ReportReceivedArguments
    let userEmail: String?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: ReportReceivedArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        getUserEmail: @escaping () -> String?,
    ) {
        self.messager = messager
        self.arguments = arguments
        userEmail = getUserEmail()
        super.init(
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .reportReceived,
            ),
        )
    }

    @Published var isLoading = false
    @Published private(set) var displayedResponse = ""
    private var nextWordIndex = 0
    private var isAnimating = false

    var model: USExaminationModelReport {
        arguments.report.actualModelReport
    }

    var response: String {
        arguments.report.actualModelReport.plainText(
            l10n: container.l10n,
        )
    }

    var isUserEmailAvailable: Bool {
        userEmail != nil
    }

    var isUserEmailButtonVisible: Bool {
        switch subscriptionAvailability(
            of: .sendingReportByEmail,
        ) {
        case .offered, .available:
            true
        case .unavailable:
            false
        }
    }

    var userEmailButtonTitle: LocalizedStringResource {
        container.l10n.resource(
            .shareWorkEmailButton,
            values: ["prefix": container.l10n.text(
                .buttonSendToEmail,
            ), "email": userEmail ?? ""],
        )
    }

    var userEmailButtonBadge: DButtonBadge? {
        switch subscriptionAvailability(
            of: .sendingReportByEmail,
        ) {
        case .offered:
            DButtonBadge(
                container.l10n[
                    .subscriptionProLabel,
                ],
                isShimmering: true,
            )
        case .available, .unavailable:
            nil
        }
    }

    func animateResponse() async {
        guard !isAnimating else { return }

        isAnimating = true
        defer { isAnimating = false }

        let words = arguments.report.actualModelReport.markdownText(
            l10n: l10n,
        ).components(
            separatedBy: " ",
        )
        while nextWordIndex < words.count {
            guard !Task.isCancelled else { return }

            let separator = nextWordIndex == 0 ? "" : " "
            let word = words[
                nextWordIndex,
            ]
            withAnimation(
                .easeIn(
                    duration: 0.3,
                ),
            ) {
                displayedResponse.append(
                    separator + word,
                )
            }
            nextWordIndex += 1

            guard nextWordIndex < words.count else { return }
            do {
                try await Task.sleep(
                    nanoseconds: 60000000,
                )
            } catch {
                return
            }
        }
    }

    func onTapReport() {
        analytics.buttonTapped(
            .reportReceivedOpen,
        )
        coordinator.dismissSheet()
        coordinator.screen(
            .reportDetail,
            arguments: ReportDetailArguments(
                report: arguments.report,
            ),
        )
    }

    func onTapUserEmail() {
        analytics.buttonTapped(
            .reportReceivedEmail,
            parameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        userEmail != nil,
                    ),
                ],
            ),
        )
        guard let userEmail: String = userEmail else { return }
        coordinator.run(
            .sendingReportByEmail,
            dismissesSheetOnPaywall: true,
        ) {
            self.sendReportEmail(
                to: userEmail,
            )
        }
    }

    func onTapCopy() {
        analytics.buttonTapped(
            .reportReceivedCopy,
        )
        UIApplication.pasteboard(
            response,
        )
        messager.show(
            type: .success,
            title: container.l10n[
                .reportReceivedCopyMessageTitle,
            ],
            description: container.l10n[
                .reportReceivedCopyMessageDescription,
            ],
        )
    }
}

private extension ReportReceivedViewModel {
    func sendReportEmail(
        to userEmail: String,
    ) {
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
                        compressionQuality: ultrasoundConfig.scanPhotoCompressionQuality,
                    ),
                    l10n: self.container.l10n,
                ),
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { _ in
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
}
