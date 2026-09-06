import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI
import UIKit

@MainActor
final class ConclusionViewModel: DViewModel {
    static let actualModelConclusionCardScrollId = "actualModelConclusionCard"

    private let messager: DMessager
    private let getNeuralModel: () -> USExaminationNeuralModel
    private let onNeuralModelSelected: (USExaminationNeuralModel) -> Void

    init(
        container: DependencyContainer,
        messager: DMessager,
        router: DRouter,
        initialConclusion: USExaminationConclusion,
        subscription: SubscriptionViewModel,
        getNeuralModel: @escaping () -> USExaminationNeuralModel,
        onNeuralModelSelected: @escaping (USExaminationNeuralModel) -> Void
    ) {
        self.messager = messager
        self.getNeuralModel = getNeuralModel
        self.onNeuralModelSelected = onNeuralModelSelected
        conclusion = initialConclusion
        super.init(
            container: container,
            router: router,
            subscription: subscription,
            analyticsDestination: .screen(.conclusion)
        )
    }

    @Published var conclusion: USExaminationConclusion
    @Published var isLoading = false

    func onTapBack() {
        analytics.buttonTapped(.conclusionBack)
        coordinator.pop()
    }

    func onTapShare() {
        analytics.buttonTapped(.conclusionShare)
        coordinator.sheet(
            .share,
            arguments: ShareArguments(
                conclusion: conclusion
            )
        )
    }

    func onTapCopy(
        conclusion: USExaminationModelConclusion
    ) {
        analytics.buttonTapped(.conclusionCopy)
        UIApplication.pasteboard(conclusion.response)
        messager.show(
            type: .success,
            title: .conclusionModelCopyMessageTitle,
            description: .conclusionModelCopyMessageDescription
        )
    }

    func onTapNeuralModelSelection() {
        analytics.buttonTapped(
            .conclusionNeuralModelSelection,
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
        analytics.buttonTapped(.conclusionNeuralModelSettings)
        coordinator.run(.neuralModelSettings) {
            self.coordinator.screen(.neuralModelSettings)
        }
    }

    func onTapRepeatScan(
        proxy: ScrollViewProxy
    ) {
        analytics.buttonTapped(
            .conclusionRepeatScan,
            parameters: AnalyticsParameters([
                .modelId: .string(getNeuralModel().id),
            ])
        )
        handle {
            try await self.coordinator.prepareConclusionGeneration()
        } onMainSuccess: { resolution in
            switch resolution {
            case .proceed:
                self.performRepeatScan(proxy: proxy)
            case .routed:
                break
            }
        }
    }

    private func performRepeatScan(
        proxy: ScrollViewProxy
    ) {
        handle {
            self.isLoading = true

            let neuralModelSettings = self.subscription.neuralModelSettings
            let template: String? = await {
                let typeId = self.conclusion.examinationData.usExaminationTypeId
                if let template = await self.container.templateRepository.getTemplatesByUSExaminationId(usExaminationTypesById: self.container.usExaminationTypesById)[typeId] {
                    return await self.container.templateRepository.getTemplate(
                        id: template.id,
                        usExaminationTypesById: self.container.usExaminationTypesById
                    )?.content
                }
                return nil
            }()
            let request = USExaminationRequest(
                neuralModelSettings: neuralModelSettings,
                examinationData: self.conclusion.examinationData,
                template: template
            )
            let ultrasoundConfig = self.container.applicationConfig.ultrasound
            let modelConclusion = try await self.container.ultrasoundConclusionRepository.generateConclusion(
                locale: Locale.current,
                request: request,
                scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                    resizeMaxDimension: ultrasoundConfig.scanPhotoResizeMaxDimension,
                    compressionQuality: ultrasoundConfig.scanPhotoCompressionQuality
                )
            )
            let updatedConclusion = USExaminationConclusion(
                id: self.conclusion.id,
                date: self.conclusion.date,
                neuralModelSettings: neuralModelSettings,
                examinationData: self.conclusion.examinationData,
                actualModelConclusion: modelConclusion,
                previosModelConclusions: [self.conclusion.actualModelConclusion] + self.conclusion.previosModelConclusions
            )
            await self.container.ultrasoundConclusionRepository.updateConclusion(
                conclusion: updatedConclusion
            )
            self.subscription.incrementRequestCount()

            return updatedConclusion
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { updatedConclusion in
            self.conclusion = updatedConclusion
            withAnimation {
                proxy.scrollTo(Self.actualModelConclusionCardScrollId, anchor: .top)
            }
            self.messager.show(
                type: .success,
                title: .conclusionModelResponseUpdatedMessageTitle,
                description: .conclusionModelResponseUpdatedMessageDescription
            )
        } onUnknownError: { _ in
            self.messager.showUnknownError()
        }
    }
}
