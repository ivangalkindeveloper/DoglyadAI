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
final class ReportDetailViewModel: DModuleViewModel<any ReportDetailStateProtocol> {
    @Published var report: USExaminationReport

    @Published var neuralModel: USExaminationNeuralModel

    @Published var template: USExaminationTemplate?

    private var reportObservation: AnyCancellable?
    private let messager: DMessager
    private let observeExaminationChanges: (@escaping () -> Void) -> AnyCancellable
    private let getSelectedTemplate: () -> USExaminationTemplate?
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) async throws -> Void
    private let currentReport: (USExaminationReport) -> USExaminationReport
    private let observeReports: (@escaping (USExaminationReport) -> Void) -> AnyCancellable
    private let onStartReportGeneration: (USExaminationRequest, USExaminationReport) async throws -> USExaminationReport
    private var examinationObservation: AnyCancellable?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        initialReport: USExaminationReport,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        observeExaminationChanges: @escaping (@escaping () -> Void) -> AnyCancellable,
        getSelectedTemplate: @escaping () -> USExaminationTemplate?,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) async throws -> Void,
        currentReport: @escaping (USExaminationReport) -> USExaminationReport,
        observeReports: @escaping (@escaping (USExaminationReport) -> Void) -> AnyCancellable,
        onStartReportGeneration: @escaping (USExaminationRequest, USExaminationReport) async throws -> USExaminationReport,
    ) {
        self.messager = messager
        self.observeExaminationChanges = observeExaminationChanges
        self.getSelectedTemplate = getSelectedTemplate
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected
        self.currentReport = currentReport
        self.observeReports = observeReports
        self.onStartReportGeneration = onStartReportGeneration

        report = currentReport(
            initialReport,
        )
        neuralModel = getNeuralModel()
        template = getSelectedTemplate()

        super.init(
            state: ReportDetailContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            analyticsDestination: .screen(
                .reportDetail,
            ),
        )
    }

    var subTitle: String {
        "\(report.examinationData.patientName), \(report.date.localizedDateTime(locale: l10n.locale))"
    }

    var selectedNeuralModelTitle: String {
        neuralModel.title
    }

    var selectedTemplate: USExaminationTemplate? {
        template
    }

    override func onInit() {
        reportObservation = observeReports { [weak self] updated in
            guard let self, report.id == updated.id else {
                return
            }
            report = updated
        }
        examinationObservation = observeExaminationChanges { [weak self] in
            guard let self else {
                return
            }
            neuralModel = getNeuralModel()
            template = getSelectedTemplate()
        }
        report = currentReport(
            report,
        )
    }

    func photoCardConfiguration(
        for photoId: UUID,
    ) -> DPhotoCardConfiguration {
        let isPhotoRemarksAvailable = report.actualModelReport.photoRemarks.contains {
            $0.photoId == photoId && !$0.points.isEmpty
        }
        return DPhotoCardConfiguration(
            badge: isPhotoRemarksAvailable ? .warning : nil,
        )
    }

    static func actualModelReportCardScrollId(
        toolbarInset: CGFloat,
    ) -> String {
        "actualModelReportCard-\(toolbarInset)"
    }

    func onTapBack() {
        analytics.buttonTapped(
            .reportDetailBack,
        )
        coordinator.pop()
    }

    func onTapShare() {
        guard report.actualModelReport.generation.status.isCompleted else {
            return
        }
        analytics.buttonTapped(
            .reportDetailShare,
        )
        coordinator.sheet(
            .share,
            arguments: ShareArguments(
                report: report,
            ),
        )
    }

    func onTapPhoto(
        _ photo: USExaminationScanPhoto,
    ) {
        switch state {
        case _ as ReportDetailGeneratingState, _ as ReportDetailLoadingState: return
        default: break
        }
        coordinator.screen(
            .photoView,
            arguments: PhotoViewArguments(
                getPhotos: { [weak self] in
                    self?.report.examinationData.photos ?? []
                },
                getPhotoRemarks: { [weak self] in
                    self?.report.actualModelReport.photoRemarks ?? []
                },
                observePhotos: { [weak self] observer in
                    self?.$report.map(
                        \.examinationData.photos,
                    ).sink(
                        receiveValue: observer,
                    ) ?? AnyCancellable {}
                },
                initialPhotoID: photo.id,
                subTitle: subTitle,
            ),
        )
    }

    func onTapNeuralModelSelection() {
        analytics.buttonTapped(
            .reportDetailNeuralModelSelection,
            parameters: AnalyticsParameters(
                [
                    .modelId: .string(
                        getNeuralModel().id,
                    ),
                ],
            ),
        )
        coordinator.sheet(
            .selectNeuralModel,
            arguments: SelectNeuralModelArguments(
                currentValue: getNeuralModel(),
                onSelected: { [weak self] model in
                    try await self?.onNeuralModelSelected(
                        model,
                    )
                },
            ),
        )
    }

    func onTapSettingsAI() {
        analytics.buttonTapped(
            .reportDetailSettingsAI,
        )
        coordinator.screen(
            .settingsAI,
        )
    }

    func onTapRepeatScan(
        proxy: ScrollViewProxy,
        toolbarInset: CGFloat,
    ) {
        switch state {
        case _ as ReportDetailGeneratingState, _ as ReportDetailLoadingState: return
        default: break
        }

        if report.actualModelReport.generation.status == .generating {
            coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedArguments(
                    isReportNavigationAvailable: false,
                    report: report,
                ),
            )
            return
        }

        analytics.buttonTapped(
            .reportDetailRepeatScan,
            parameters: AnalyticsParameters(
                [
                    .modelId: .string(
                        getNeuralModel().id,
                    ),
                ],
            ),
        )
        handle {
            try await self.coordinator.prepareReportGeneration()
        } onMainSuccess: { resolution in
            switch resolution {
            case .proceed:
                self.performRepeatScan(
                    proxy: proxy,
                    toolbarInset: toolbarInset,
                )
            case .routed:
                break
            }
        }
    }

    func onTapCopy(
        report: USExaminationModelReport,
    ) {
        guard report.generation.status.isCompleted else {
            return
        }
        analytics.buttonTapped(
            .reportDetailCopy,
        )
        UIApplication.pasteboard(
            report.plainText(
                l10n: container.l10n,
            ),
        )
        messager.show(
            type: .success,
            title: container.l10n[
                .reportDetailModelCopyMessageTitle,
            ],
            description: container.l10n[
                .reportDetailModelCopyMessageDescription,
            ],
        )
    }

    private func performRepeatScan(
        proxy _: ScrollViewProxy,
        toolbarInset _: CGFloat,
    ) {
        switch state {
        case _ as ReportDetailGeneratingState, _ as ReportDetailLoadingState: return
        default: break
        }
        if report.actualModelReport.generation.status == .generating {
            coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedArguments(
                    isReportNavigationAvailable: false,
                    report: report,
                ),
            )
            return
        }
        let original = report
        emit(
            ReportDetailGeneratingState(),
        )
        handle {
            let settings = self.settingsAI
            let request = try await USExaminationRequest(
                settingsAI: settings,
                examinationData: original.examinationData,
                template: self.getSelectedTemplate()?.content,
                isRecommendationsIncluded: self.container.userSettingsRepository.getIsRecommendationsIncluded(),
                isPhotoRemarks: self.container.userSettingsRepository.getIsPhotoRemarks(),
                isDescriptionRemarks: self.container.userSettingsRepository.getIsDescriptionRemarks(),
            )
            return try await self.onStartReportGeneration(
                request,
                original,
            )
        } onMainSuccess: { candidate in
            self.report = candidate
            self.emit(
                ReportDetailContentState(),
            )
            self.coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedArguments(
                    isReportNavigationAvailable: false,
                    report: candidate,
                ),
            )
        } onMainApiError: { error in
            self.onGenerationFailed(
                error,
            )
        } onMainConnectionError: { error in
            self.onGenerationFailed(
                error,
            )
        } onMainUnknownError: { error in
            self.onGenerationFailed(
                error,
            )
        }
    }

    private func onGenerationFailed(
        _ error: Error,
    ) {
        emit(
            ReportDetailFailedState(
                error: error,
            ),
        )
        messager.showUnknownError(
            l10n: l10n,
        )
    }
}
