import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class HistoryViewModel: DViewModel {
    private let container: DependencyContainer
    private let router: DRouter
    private let sectionBuilder: HistoryDaySectionBuilder
    private let historyConfig: HistoryConfig

    private var offset = 0
    private var loadedConclusionIds = Set<UUID>()
    private var offsetLoadingTask: Task<Void, Never>?

    init(
        container: DependencyContainer,
        router: DRouter,
        sectionBuilder: HistoryDaySectionBuilder = HistoryDaySectionBuilder()
    ) {
        self.container = container
        self.router = router
        self.sectionBuilder = sectionBuilder
        historyConfig = container.applicationConfig.history
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
        router.pop()
    }

    func onTapConclusion(
        value: USExaminationConclusion
    ) {
        router.push(
            route: RouteScreen(
                type: .conclusion,
                arguments: ConclusionScreenArguments(
                    conclusion: value
                )
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
