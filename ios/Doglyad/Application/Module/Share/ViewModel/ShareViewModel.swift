import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import NestedObservableObject
import Router
import UIKit

@MainActor
final class ShareViewModel: DModuleViewModel<any ShareStateProtocol> {
    let report: USExaminationReport

    let userEmail: String?

    private let examinationTypesById: [String: USExaminationType]

    private let messager: DMessager

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        arguments: ShareArguments,
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

        examinationTypesById = container.usExaminationTypesById

        super.init(
            state: ShareReadyState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .bottomSheet(
                .share,
            ),
        )
    }

    var userEmailButtonTitle: String {
        l10n.text(
            .shareWorkEmailButton,
            values: ["prefix": l10n.text(
                .buttonSendToEmail,
            ), "email": userEmail ?? ""],
        )
    }

    var subject: String {
        report.shareSubject(
            examinationTypesById: examinationTypesById,
            l10n: l10n,
        )
    }

    var shareMessage: String {
        report.shareMessage(
            l10n: l10n,
        )
    }

    func onTapUserEmail() {
        analytics.buttonTapped(
            .shareUserEmail,
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

    func onTapEmail() {
        analytics.buttonTapped(
            .shareCustomEmail,
        )
        coordinator.run(
            .sendingReportByEmail,
            isSheetDismissedOnPaywall: true,
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

private extension ShareViewModel {
    func sendReportEmail(
        to userEmail: String,
    ) {
        switch state {
        case _ as ShareSendingState: return
        default: break
        }
        emit(
            ShareSendingState(),
        )
        let ultrasoundConfig = container.applicationConfig.ultrasound
        handle {
            try await self.container.userSettingsRepository.sendEmail(
                email: self.report.makeEmail(
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
            case _ as ShareSendingState: self.emit(
                    ShareReadyState(),
                )
            default: break
            }
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
        } onMainUnknownError: { error in
            self.emit(
                ShareFailedState(
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }
}
