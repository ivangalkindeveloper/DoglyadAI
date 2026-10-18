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

    private let messager: DMessager
    private let getSelectedTemplate: () -> USExaminationTemplate?
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) async throws -> Void
    private var examinationObservation: AnyCancellable?

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        initialReport: USExaminationReport,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        observeExaminationChanges: @escaping (@escaping () -> Void) -> AnyCancellable,
        getSelectedTemplate: @escaping () -> USExaminationTemplate?,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) async throws -> Void,
    ) {
        self.messager = messager
        self.getSelectedTemplate = getSelectedTemplate
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected

        report = initialReport
        neuralModel = getNeuralModel()
        template = getSelectedTemplate()

        super.init(
            state: ReportDetailContentState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .reportDetail,
            ),
        )
        examinationObservation = observeExaminationChanges { [weak self] in
            guard let self else { return }
            neuralModel = getNeuralModel()
            template = getSelectedTemplate()
        }
    }

    var subTitle: String {
        "\(report.examinationData.patientName), \(report.date.localizedDateTime(locale: l10n.locale))"
    }

    var selectedNeuralModelTitle: String { neuralModel.title }

    var selectedTemplate: USExaminationTemplate? { template }

    func photoCardConfiguration(
        for photoId: UUID,
    ) -> PhotoCardConfiguration {
        let isPhotoRemarksAvailable = report.actualModelReport.photoRemarks.contains {
            $0.photoId == photoId && !$0.points.isEmpty
        }
        return PhotoCardConfiguration(
            badge: isPhotoRemarksAvailable ? .warning(
                accessibilityLabel: l10n[
                    .reportDetailPhotoRemarksLabel,
                ],
            ) : nil,
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
                getPhotos: { [weak self] in self?.report.examinationData.photos ?? [] },
                getPhotoRemarks: { [weak self] in self?.report.actualModelReport.photoRemarks ?? [] },
                observePhotos: { [weak self] observer in self?.$report.map(
                    \.examinationData.photos,
                ).sink(
                    receiveValue: observer,
                ) ?? AnyCancellable {} },
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

    func onTapNeuralModelSettings() {
        analytics.buttonTapped(
            .reportDetailNeuralModelSettings,
        )
        coordinator.run(
            .neuralModelSettings,
        ) {
            self.coordinator.screen(
                .neuralModelSettings,
            )
        }
    }

    func onTapRepeatScan(
        proxy: ScrollViewProxy,
        toolbarInset: CGFloat,
    ) {
        switch state {
        case _ as ReportDetailGeneratingState, _ as ReportDetailLoadingState: return
        case let state as ReportDetailSaveFailedState:
            persistReport(
                state.candidate,
                proxy: proxy,
                toolbarInset: toolbarInset,
            )
            return
        default: break
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
        proxy: ScrollViewProxy,
        toolbarInset: CGFloat,
    ) {
        switch state {
        case _ as ReportDetailGeneratingState, _ as ReportDetailLoadingState: return
        default: break
        }
        let original = report
        emit(
            ReportDetailGeneratingState(),
        )
        handle {
            let settings = self.neuralModelSettings
            let request = try await USExaminationRequest(
                neuralModelSettings: settings,
                examinationData: original.examinationData,
                template: self.getSelectedTemplate()?.content,
                isRecommendationsIncluded: self.container.userSettingsRepository.getIsRecommendationsIncluded(),
                isPhotoRemarks: self.container.userSettingsRepository.getIsPhotoRemarks(),
                isDescriptionRemarks: self.container.userSettingsRepository.getIsDescriptionRemarks(),
            )
            let config = self.container.applicationConfig.ultrasound
            let response = try await self.container.ultrasoundReportRepository.generateReport(
                locale: self.container.language.currentLocale,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: config.scanPhotoResizeMaxDimension,
                    compressionQuality: config.scanPhotoCompressionQuality,
                ),
            )
            return USExaminationReport(
                id: original.id,
                date: original.date,
                neuralModelSettings: settings,
                examinationData: original.examinationData,
                actualModelReport: response,
                previousModelReports: [original.actualModelReport] + original.previousModelReports,
            )
        } onMainSuccess: { candidate in
            self.persistReport(
                candidate,
                proxy: proxy,
                toolbarInset: toolbarInset,
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

    private func persistReport(
        _ candidate: USExaminationReport,
        proxy: ScrollViewProxy,
        toolbarInset: CGFloat,
    ) {
        emit(
            ReportDetailLoadingState(
                candidate: candidate,
            ),
        )
        handle {
            try await self.container.ultrasoundReportRepository.updateReport(
                report: candidate,
            )
            self.incrementRequestCount()
        } onMainSuccess: { _ in
            withAnimation(
                DTheme.light.animation,
            ) {
                self.report = candidate
                self.emit(
                    ReportDetailContentState(),
                )
            }
            withAnimation {
                proxy.scrollTo(
                    Self.actualModelReportCardScrollId(
                        toolbarInset: toolbarInset,
                    ),
                    anchor: .top,
                )
            }
            self.messager.show(
                type: .success,
                title: self.l10n[
                    .reportDetailModelResponseUpdatedMessageTitle,
                ],
                description: self.l10n[
                    .reportDetailModelResponseUpdatedMessageDescription,
                ],
            )
        } onMainUnknownError: { error in
            self.emit(
                ReportDetailSaveFailedState(
                    candidate: candidate,
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
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
