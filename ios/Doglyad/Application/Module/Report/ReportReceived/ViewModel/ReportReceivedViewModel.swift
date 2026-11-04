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
    let isReportNavigationAvailable: Bool
    private var reportObservation: AnyCancellable?
    private var retryTask: Task<Void, Never>?

    let userEmail: String?

    private let messager: DMessager
    private let currentReport: (USExaminationReport) -> USExaminationReport
    private let observeReports: (@escaping (USExaminationReport) -> Void) -> AnyCancellable
    private let retryGeneration: (USExaminationReport) async throws -> USExaminationReport

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: ReportReceivedArguments,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        getUserEmail: @escaping () -> String?,
        currentReport: @escaping (USExaminationReport) -> USExaminationReport,
        observeReports: @escaping (@escaping (USExaminationReport) -> Void) -> AnyCancellable,
        retryGeneration: @escaping (USExaminationReport) async throws -> USExaminationReport,
    ) {
        self.messager = messager
        self.currentReport = currentReport
        self.observeReports = observeReports
        self.retryGeneration = retryGeneration

        isReportNavigationAvailable = arguments.isReportNavigationAvailable
        let report = currentReport(
            arguments.report,
        )
        userEmail = getUserEmail()

        super.init(
            state: ReportReceivedDefaultState(
                report: report,
            ),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .bottomSheet(
                .reportReceived,
            ),
        )
    }

    var report: USExaminationReport {
        state.report
    }

    var actualModelReport: USExaminationModelReport {
        report.actualModelReport
    }

    var isCompleted: Bool {
        actualModelReport.generation.status.isCompleted
    }

    var isGenerating: Bool {
        actualModelReport.generation.status == .generating
    }

    var isWaitingForFirstToken: Bool {
        isGenerating && displayedMarkdownText.isEmpty
    }

    var generationFailureTitle: L10NKey? {
        switch actualModelReport.generation.status {
        case .generating, .completed: nil
        case .interrupted: .reportGenerationInterruptedLabel
        case .failed, .cancelled: .reportGenerationIncompleteLabel
        }
    }

    var canRetry: Bool {
        switch actualModelReport.generation.status {
        case .generating, .completed: false
        case .interrupted, .failed, .cancelled: true
        }
    }

    var displayedMarkdownText: String {
        actualModelReport.markdownText(
            l10n: l10n,
        )
    }

    var response: String {
        actualModelReport.plainText(
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

    override func onInit() {
        reportObservation = observeReports { [weak self] updated in
            guard let self, updated.id == self.report.id else {
                return
            }
            switch state {
            case _ as ReportReceivedSendingState:
                emit(
                    ReportReceivedSendingState(
                        report: updated,
                    ),
                )
            default:
                emit(
                    ReportReceivedDefaultState(
                        report: updated,
                    ),
                )
            }
        }
        emit(
            ReportReceivedDefaultState(
                report: currentReport(
                    report,
                ),
            ),
        )
    }

    func onTapRetryGeneration() {
        guard retryTask == nil else {
            return
        }
        retryTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                retryTask = nil
            }
            do {
                let updated = try await retryGeneration(
                    report,
                )
                emit(
                    ReportReceivedDefaultState(
                        report: updated,
                    ),
                )
            } catch {
                messager.showUnknownError(
                    l10n: l10n,
                )
            }
        }
    }

    func onTapReport() {
        guard isCompleted, isReportNavigationAvailable else {
            return
        }
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
        guard isCompleted else {
            return
        }
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
        guard let userEmail else {
            return
        }
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
        guard isCompleted else {
            return
        }
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

    private func sendReportEmail(
        to userEmail: String,
    ) {
        switch state {
        case _ as ReportReceivedSendingState: return
        default: break
        }
        emit(
            ReportReceivedSendingState(
                report: report,
            ),
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
                    ReportReceivedDefaultState(
                        report: self.report,
                    ),
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
                    report: self.report,
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
