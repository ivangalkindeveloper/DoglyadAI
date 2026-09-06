import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class HistoryViewModel: DViewModel {
    private let sectionBuilder: HistoryDaySectionBuilder
    private let historyConfig: HistoryConfig

    private var offset = 0
    private var loadedConclusionIds = Set<UUID>()
    private var offsetLoadingTask: Task<Void, Never>?

    init(
        container: DependencyContainer,
        router: DRouter,
        subscription: SubscriptionViewModel,
        sectionBuilder: HistoryDaySectionBuilder = HistoryDaySectionBuilder()
    ) {
        self.sectionBuilder = sectionBuilder
        historyConfig = container.applicationConfig.history
        super.init(
            container: container,
            router: router,
            subscription: subscription
        )
    }

    override func onInit() {
        loadInitialPage()
    }

    @Published private(set) var sections: [HistoryDaySection] = []
    @Published private(set) var isLoading = true
    @Published private(set) var hasMoreOffset = false

    var pageSize: Int {
        historyConfig.pageSize
    }

    var isEmpty: Bool {
        sections.isEmpty
    }

    func onTapBack() {
        coordinator.pop()
    }

    func onTapConclusion(
        value: USExaminationConclusion
    ) {
        coordinator.screen(
            .conclusion,
            arguments: ConclusionScreenArguments(
                conclusion: value
            )
        )
    }

    func onOffsetAppear() {
        loadNextOffset()
    }

    private func loadInitialPage() {
        handle {
            await self.container.ultrasoundConclusionRepository.getConclusions(
                limit: self.pageSize,
                offset: 0
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { conclusions in
            self.append(conclusions)
        }
    }

    private func loadNextOffset() {
        guard hasMoreOffset, offsetLoadingTask == nil else { return }

        let requestedOffset = offset
        offsetLoadingTask = handle {
            await self.container.ultrasoundConclusionRepository.getConclusions(
                limit: self.pageSize,
                offset: requestedOffset
            )
        } onDefer: {
            self.offsetLoadingTask = nil
        } onMainSuccess: { conclusions in
            self.append(conclusions)
        }
    }

    private func append(_ conclusions: [USExaminationConclusion]) {
        offset += conclusions.count
        hasMoreOffset = conclusions.count == pageSize

        let uniqueConclusions = conclusions.filter {
            loadedConclusionIds.insert($0.id).inserted
        }
        sections = sectionBuilder.appending(
            uniqueConclusions,
            to: sections
        )
    }
}
