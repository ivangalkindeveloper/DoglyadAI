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
    private var loadedReportIds = Set<UUID>()
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
            subscription: subscription,
            analyticsDestination: .screen(.history)
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
        analytics.buttonTapped(.historyBack)
        coordinator.pop()
    }

    func onTapReport(
        value: USExaminationReport
    ) {
        analytics.buttonTapped(.historyReport)
        coordinator.screen(
            .reportDetail,
            arguments: ReportDetailScreenArguments(
                report: value
            )
        )
    }

    func onOffsetAppear() {
        loadNextOffset()
    }

    private func loadInitialPage() {
        handle {
            await self.container.ultrasoundReportRepository.getReports(
                limit: self.pageSize,
                offset: 0
            )
        } onDefer: {
            self.isLoading = false
        } onMainSuccess: { reports in
            self.append(reports)
        }
    }

    private func loadNextOffset() {
        guard hasMoreOffset, offsetLoadingTask == nil else { return }

        let requestedOffset = offset
        offsetLoadingTask = handle {
            await self.container.ultrasoundReportRepository.getReports(
                limit: self.pageSize,
                offset: requestedOffset
            )
        } onDefer: {
            self.offsetLoadingTask = nil
        } onMainSuccess: { reports in
            self.append(reports)
        }
    }

    private func append(_ reports: [USExaminationReport]) {
        offset += reports.count
        hasMoreOffset = reports.count == pageSize

        let uniqueReports = reports.filter {
            loadedReportIds.insert($0.id).inserted
        }
        sections = sectionBuilder.appending(
            uniqueReports,
            to: sections
        )
    }
}
