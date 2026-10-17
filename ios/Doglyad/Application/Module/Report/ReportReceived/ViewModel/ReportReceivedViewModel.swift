import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import SwiftUI
import UIKit

@MainActor
final class ReportReceivedViewModel: DModuleViewModel<any ReportReceivedStateProtocol> {
    let report: USExaminationReport

    let userEmail: String?

    var model: USExaminationModelReport {
        report.actualModelReport
    }

    var displayedMarkdownText: String {
        var text = model.markdownText(
            l10n: l10n,
        )
        if let remarks = model.descriptionRemarks {
            text += "\n\n## \(String(localized: l10n[.reportDescriptionRemarksTitle]))\n\(remarks)"
        }
        return text
    }

    var response: String {
        report.actualModelReport.plainText(
            l10n: l10n,
        )
    }

    var userEmailButtonTitle: LocalizedStringResource {
        l10n[
            .buttonSendToEmail,
        ]
    }

    var userEmailButtonBadge: DButtonBadge? {
        switch subscriptionAvailability(
            of: .sendingReportByEmail,
        ) {
        case .offered:
            DButtonBadge(
                l10n[
                    .subscriptionProLabel,
                ],
                isShimmering: true,
            )
        case .available, .unavailable:
            nil
        }
    }

    @Published private(set) var responseText = ""
    private var nextWordIndex = 0
    private let messager: DMessager

    private var animationRunID: UUID?

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

        report = (arguments.report)
        userEmail = getUserEmail()

        super.init(
            state: ReportReceivedDefaultState(),
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

    func animateResponse() async {
        guard animationRunID == nil else { return }
        animationRunID = UUID()
        defer { animationRunID = nil }
        let words = displayedMarkdownText.components(
            separatedBy: " ",
        )
        while !Task.isCancelled, nextWordIndex < words.count {
            let word = words[
                nextWordIndex,
            ]
            withAnimation(
                .easeIn(
                    duration: 0.3,
                ),
            ) {
                responseText += (nextWordIndex == 0 ? "" : " ") + word
                nextWordIndex += 1
            }
            do { try await Task.sleep(
                nanoseconds: 60000000,
            ) } catch { return }
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
                report: report,
            ),
        )
    }

    func onTapUserEmail() {
        analytics.buttonTapped(
            .reportReceivedEmail,
            parameters: AnalyticsParameters(
                [
                    .hasCurrentValue: .bool(
                        self.userEmail != nil,
                    ),
                ],
            ),
        )
        guard let userEmail else { return }
        coordinator.run(
            .sendingReportByEmail,
            isSheetDismissedOnPaywall: true,
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
        switch state {
        case _ as ReportReceivedSendingState: return
        default: break
        }
        emit(
            ReportReceivedSendingState(),
        )
        let report = report
        let ultrasoundConfig = container.applicationConfig.ultrasound
        handle {
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
            switch self.state {
            case _ as ReportReceivedSendingState:
                self.emit(
                    ReportReceivedDefaultState(),
                )
            default: break
            }
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
        } onMainUnknownError: { error in
            self.emit(
                ReportReceivedDeliveryFailedState(
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
