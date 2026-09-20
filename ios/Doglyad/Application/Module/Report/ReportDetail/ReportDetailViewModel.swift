import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI
import UIKit

@MainActor
final class ReportDetailViewModel: DViewModel {
    static func actualModelReportCardScrollId(toolbarInset: CGFloat) -> String {
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
        subscription: SubscriptionViewModel,
        getSelectedTemplate: @escaping () -> USExaminationTemplate?,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.messager = messager
        self.getSelectedTemplate = getSelectedTemplate
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected
        report = initialReport
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.reportDetail)
        )
    }

    @Published var report: USExaminationReport
    @Published var isLoading = false

    var subTitle: String {
        "\(report.examinationData.patientName), \(report.date.localized())"
    }

    func onTapPhoto(_ photo: USExaminationScanPhoto) {
        guard !isLoading else { return }
        coordinator.screen(
            .photoView,
            arguments: PhotoViewScreenArguments(
                photos: .constant(report.examinationData.photos),
                initialPhotoID: photo.id,
                subTitle: subTitle
            )
        )
    }

    func onTapBack() {
        analytics.buttonTapped(.reportDetailBack)
        coordinator.pop()
    }

    func onTapShare() {
        analytics.buttonTapped(.reportDetailShare)
        coordinator.sheet(
            .share,
            arguments: ShareArguments(
                report: report
            )
        )
    }

    func onTapCopy(
        report: USExaminationModelReport
    ) {
        analytics.buttonTapped(.reportDetailCopy)
        UIApplication.pasteboard(report.plainText)
        messager.show(
            type: .success,
            title: .reportDetailModelCopyMessageTitle,
            description: .reportDetailModelCopyMessageDescription
        )
    }

    func onTapNeuralModelSelection() {
        analytics.buttonTapped(
            .reportDetailNeuralModelSelection,
            parameters: AnalyticsParameters([
                .modelId: .string(getNeuralModel().id),
            ])
        )
        coordinator.sheet(
            .selectNeuralModel,
            arguments: SelectNeuralModelArguments(
                currentValue: getNeuralModel(),
                onSelected: { [weak self] model in
                    self?.onNeuralModelSelected(model)
                }
            )
        )
    }

    func onTapNeuralModelSettings() {
        analytics.buttonTapped(.reportDetailNeuralModelSettings)
        coordinator.run(.neuralModelSettings) {
            self.coordinator.screen(.neuralModelSettings)
        }
    }

    func onTapRepeatScan(
        proxy: ScrollViewProxy,
        toolbarInset: CGFloat
    ) {
        analytics.buttonTapped(
            .reportDetailRepeatScan,
            parameters: AnalyticsParameters([
                .modelId: .string(getNeuralModel().id),
            ])
        )
        handle {
            try await self.coordinator.prepareReportGeneration()
        } onMainSuccess: { resolution in
            switch resolution {
            case .proceed:
                self.performRepeatScan(
                    proxy: proxy,
                    toolbarInset: toolbarInset
                )
            case .routed:
                break
            }
        }
    }

    private func performRepeatScan(
        proxy: ScrollViewProxy,
        toolbarInset: CGFloat
    ) {
        handle {
            self.isLoading = true

            let neuralModelSettings = self.subscription.neuralModelSettings
            let request = USExaminationRequest(
                neuralModelSettings: neuralModelSettings,
                examinationData: self.report.examinationData,
                template: self.getSelectedTemplate()?.content,
                includeRecommendations: self.container.userSettingsRepository.getIncludeRecommendations()
            )
            let ultrasoundConfig = self.container.applicationConfig.ultrasound
            let modelReport = try await self.container.ultrasoundReportRepository.generateReport(
                locale: Locale.current,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: ultrasoundConfig.scanPhotoResizeMaxDimension,
                    compressionQuality: ultrasoundConfig.scanPhotoCompressionQuality
                )
            )
            let updatedReport = USExaminationReport(
                id: self.report.id,
                date: self.report.date,
                neuralModelSettings: neuralModelSettings,
                examinationData: self.report.examinationData,
                actualModelReport: modelReport,
                previousModelReports: [self.report.actualModelReport] + self.report.previousModelReports
            )
            await self.container.ultrasoundReportRepository.updateReport(
                report: updatedReport
            )
            self.subscription.incrementRequestCount()

            return updatedReport
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { updatedReport in
            self.report = updatedReport
            withAnimation {
                proxy.scrollTo(
                    Self.actualModelReportCardScrollId(toolbarInset: toolbarInset),
                    anchor: .top
                )
            }
            self.messager.show(
                type: .success,
                title: .reportDetailModelResponseUpdatedMessageTitle,
                description: .reportDetailModelResponseUpdatedMessageDescription
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }
}
