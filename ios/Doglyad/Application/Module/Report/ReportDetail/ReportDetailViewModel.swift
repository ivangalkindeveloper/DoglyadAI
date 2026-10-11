import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI
import UIKit

@MainActor
final class ReportDetailViewModel: DModuleViewModel {
    static func actualModelReportCardScrollId(
        toolbarInset: CGFloat,
    ) -> String {
        "actualModelReportCard-\(toolbarInset)"
    }

    private let messager: DMessager
    private let getSelectedTemplate: () -> USExaminationTemplate?
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) -> Void

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
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void,
    ) {
        self.messager = messager
        self.getSelectedTemplate = getSelectedTemplate
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected
        report = initialReport
        super.init(
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
        observePresentationChanges(
            observeExaminationChanges,
        )
    }

    @Published var report: USExaminationReport
    @Published var isLoading = false

    var subTitle: String {
        "\(report.examinationData.patientName), \(report.date.localizedDateTime())"
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
        guard !isLoading else { return }
        coordinator.screen(
            .photoView,
            arguments: PhotoViewArguments(
                getPhotos: { [weak self] in self?.report.examinationData.photos ?? [] },
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
                    self?.onNeuralModelSelected(
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
        handle {
            self.isLoading = true

            let neuralModelSettings = self.neuralModelSettings
            let locale = self.container.language.currentLocale
            let request = USExaminationRequest(
                neuralModelSettings: neuralModelSettings,
                examinationData: self.report.examinationData,
                template: self.getSelectedTemplate()?.content,
                includeRecommendations: self.container.userSettingsRepository.getIncludeRecommendations(),
            )
            let ultrasoundConfig = self.container.applicationConfig.ultrasound
            let modelReport = try await self.container.ultrasoundReportRepository.generateReport(
                locale: locale,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: ultrasoundConfig.scanPhotoResizeMaxDimension,
                    compressionQuality: ultrasoundConfig.scanPhotoCompressionQuality,
                ),
            )
            let updatedReport = USExaminationReport(
                id: self.report.id,
                date: self.report.date,
                neuralModelSettings: neuralModelSettings,
                examinationData: self.report.examinationData,
                actualModelReport: modelReport,
                previousModelReports: [self.report.actualModelReport] + self.report.previousModelReports,
            )
            await self.container.ultrasoundReportRepository.updateReport(
                report: updatedReport,
            )
            self.incrementRequestCount()

            return updatedReport
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { updatedReport in
            self.report = updatedReport
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
                title: self.container.l10n[
                    .reportDetailModelResponseUpdatedMessageTitle,
                ],
                description: self.container.l10n[
                    .reportDetailModelResponseUpdatedMessageDescription,
                ],
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError(
                l10n: self.container.l10n,
            )
        }
    }

    var selectedNeuralModelTitle: String { getNeuralModel().title }
    var selectedTemplate: USExaminationTemplate? { getSelectedTemplate() }
}
