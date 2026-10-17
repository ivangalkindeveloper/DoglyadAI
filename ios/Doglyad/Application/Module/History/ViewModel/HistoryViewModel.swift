import Combine
import DoglyadNetwork
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class HistoryViewModel: DModuleViewModel<any HistoryStateProtocol> {
    @Published private(set) var sections: [HistoryDaySection] = []
    private(set) var nextOffset: Int?

    private let sectionBuilder: HistoryDaySectionBuilder
    private let historyConfig: HistoryConfig

    private var offsetLoadingTask: Task<Void, Never>?

    var pageSize: Int {
        historyConfig.pageSize
    }

    init(
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getNeuralModelSettings: @escaping () -> NeuralModelSettings,
        onRequestCountIncremented: @escaping () -> Void,
        sectionBuilder: HistoryDaySectionBuilder? = nil,
    ) {
        self.sectionBuilder = sectionBuilder ?? HistoryDaySectionBuilder(
            todayTitle: container.l10n.text(
                .dateTodayLabel,
            ),
            yesterdayTitle: container.l10n.text(
                .dateYesterdayLabel,
            ),
            locale: container.language.currentLocale,
        )
        historyConfig = container.applicationConfig.history
        super.init(
            state: HistoryLoadingState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            getNeuralModelSettings: getNeuralModelSettings,
            onRequestCountIncremented: onRequestCountIncremented,
            analyticsDestination: .screen(
                .history,
            ),
        )
    }

    override func onInit() {
        loadInitialPage()
    }

    func onTapBack() {
        analytics.buttonTapped(
            .historyBack,
        )
        coordinator.pop()
    }

    func onTapReport(
        value: USExaminationReport,
    ) {
        analytics.buttonTapped(
            .historyReport,
        )
        coordinator.screen(
            .reportDetail,
            arguments: ReportDetailArguments(
                report: value,
            ),
        )
    }

    func onTapRetry() { loadInitialPage() }

    func onOffsetAppear() {
        loadNextOffset()
    }

    private func loadInitialPage() {
        emit(
            HistoryLoadingState(),
        )
        handle {
            try await self.container.ultrasoundReportRepository.getReports(
                limit: self.pageSize,
                offset: 0,
            )
        } onMainSuccess: { reports in
            self.append(
                reports,
                to: [],
                offset: 0,
            )
        } onMainUnknownError: { error in
            self.emit(
                HistoryFailedState(
                    error: error,
                ),
            )
        }
    }

    private func loadNextOffset() {
        guard offsetLoadingTask == nil, let offset = nextOffset else { return }
        switch state { case _ as HistoryLoadingState: return; default: break }
        emit(
            HistoryLoadingState(),
        )
        offsetLoadingTask = handle {
            try await self.container.ultrasoundReportRepository.getReports(
                limit: self.pageSize,
                offset: offset,
            )
        } onDefer: { self.offsetLoadingTask = nil }
            onMainSuccess: { reports in self.append(
                reports,
                to: self.sections,
                offset: offset,
            ) }
            onMainUnknownError: { error in self.emit(
                HistoryFailedState(
                    error: error,
                ),
            ) }
    }

    private func append(
        _ reports: [USExaminationReport],
        to sections: [HistoryDaySection],
        offset: Int,
    ) {
        var ids = Set(
            sections.flatMap { $0.reports.map(
                \.id,
            ) },
        )
        let uniqueReports = reports.filter { ids.insert(
            $0.id,
        ).inserted }
        let updated = sectionBuilder.appending(
            uniqueReports,
            to: sections,
        )
        guard !updated.isEmpty else { emit(
            HistoryEmptyState(),
        )
        return
        }
        self.sections = updated
        nextOffset = reports.count == pageSize ? offset + reports.count : nil
        emit(
            HistoryContentState(),
        )
    }
}
