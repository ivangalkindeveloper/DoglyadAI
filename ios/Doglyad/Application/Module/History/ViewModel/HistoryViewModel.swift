import Combine
import DoglyadNetwork
import DoglyadUI
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class HistoryViewModel: DModuleViewModel<any HistoryStateProtocol> {
    private let messager: DMessager
    @Published private(set) var sections: [HistoryDaySection] = []
    private(set) var nextOffset: Int?
    private var reportObservation: AnyCancellable?
    private let currentReport: (USExaminationReport) -> USExaminationReport
    private let observeReports: (@escaping (USExaminationReport) -> Void) -> AnyCancellable
    private let sectionBuilder: HistoryDaySectionBuilder
    private let historyConfig: HistoryConfig
    private var offsetLoadingID: UUID?
    private var offsetLoadingTask: Task<Void, Never>?

    #if DEBUG
        private var isPreview = false
    #endif

    init(
        messager: DMessager,
        container: DependencyContainer,
        router: DRouter,
        getSubscriptionStatus: @escaping () -> SubscriptionStatus?,
        observeSubscriptionStatus: @escaping (@escaping (SubscriptionStatus?) -> Void) -> AnyCancellable,
        onSubscriptionStatusUpdated: @escaping (SubscriptionStatus?) -> Void,
        getSettingsAI: @escaping () -> SettingsAI,
        onRefreshSubscriptionStatus: @escaping () async -> Void,
        currentReport: @escaping (USExaminationReport) -> USExaminationReport,
        observeReports: @escaping (@escaping (USExaminationReport) -> Void) -> AnyCancellable,
        sectionBuilder: HistoryDaySectionBuilder? = nil,
    ) {
        self.messager = messager
        self.currentReport = currentReport
        self.observeReports = observeReports
        self.sectionBuilder = sectionBuilder ?? HistoryDaySectionBuilder(
            locale: container.language.currentLocale,
            todayTitle: container.l10n.text(
                .dateTodayLabel,
            ),
            yesterdayTitle: container.l10n.text(
                .dateYesterdayLabel,
            ),
        )
        historyConfig = container.applicationConfig.history
        super.init(
            state: HistoryInitialState(),
            container: container,
            router: router,
            getSubscriptionStatus: getSubscriptionStatus,
            observeSubscriptionStatus: observeSubscriptionStatus,
            getSettingsAI: getSettingsAI,
            onRefreshSubscriptionStatus: onRefreshSubscriptionStatus,
            onSubscriptionStatusUpdated: onSubscriptionStatusUpdated,
            analyticsDestination: .screen(
                .history,
            ),
        )
    }

    var pageSize: Int {
        historyConfig.pageSize
    }

    override func onInit() {
        reportObservation = observeReports { [weak self] report in
            guard let self else {
                return
            }
            var values = sections.flatMap(
                \.reports,
            )
            if let index = values.firstIndex(
                where: {
                    $0.id == report.id
                },
            ) {
                let previous = values[
                    index,
                ].actualModelReport
                guard previous.generation.status != report.actualModelReport.generation.status || previous.generation.id != report.actualModelReport.generation.id else {
                    return
                }
                values[
                    index,
                ] = report
            } else {
                values.append(
                    report,
                )
            }
            sections = sectionBuilder.appending(
                values.sorted {
                    $0.date > $1.date
                },
                to: [],
            )
        }
        loadInitialPage()
    }

    #if DEBUG
        func configurePreview(
            state: any HistoryStateProtocol,
            reports: [USExaminationReport],
            nextOffset: Int? = nil,
        ) {
            isPreview = true
            sections = sectionBuilder.appending(
                reports,
                to: [],
            )
            self.nextOffset = nextOffset
            emit(
                state,
                animation: nil,
            )
        }
    #endif

    override func onDisappear() {
        super.onDisappear()
        offsetLoadingTask?.cancel()
        offsetLoadingTask = nil
        offsetLoadingID = nil
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
        let value = currentReport(
            value,
        )
        if value.actualModelReport.generation.status == .generating {
            coordinator.sheet(
                .reportReceived,
                arguments: ReportReceivedArguments(
                    report: value,
                ),
            )
            return
        }
        coordinator.screen(
            .reportDetail,
            arguments: ReportDetailArguments(
                report: value,
            ),
        )
    }

    func onTapRetry() {
        loadInitialPage()
    }

    func onOffsetAppear() {
        loadNextOffset()
    }

    private func loadInitialPage() {
        #if DEBUG
            guard !isPreview else {
                return
            }
        #endif

        cancelOperationTask()
        offsetLoadingTask?.cancel()
        offsetLoadingTask = nil
        offsetLoadingID = nil
        performLocalOperation {
            try await self.container.ultrasoundReportRepository.getReports(
                limit: self.pageSize,
                offset: 0,
            )
        } onSuccess: { reports in
            self.append(
                reports.map(
                    self.currentReport,
                ),
                to: [],
                offset: 0,
            )
        } onFailure: { error in
            self.emit(
                HistoryErrorState(
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    private func loadNextOffset() {
        #if DEBUG
            guard !isPreview else {
                return
            }
        #endif
        guard offsetLoadingTask == nil, let offset = nextOffset else {
            return
        }

        let id = UUID()
        offsetLoadingID = id
        offsetLoadingTask = handle {
            try await self.container.ultrasoundReportRepository.getReports(
                limit: self.pageSize,
                offset: offset,
            )
        } onDefer: {
            if self.offsetLoadingID == id {
                self.offsetLoadingTask = nil
            }
        }
        onMainSuccess: { reports in
            self.append(
                reports.map(
                    self.currentReport,
                ),
                to: self.sections,
                offset: offset,
            )
        }
        onMainUnknownError: { error in
            guard !Task.isCancelled else {
                return
            }
            self.emit(
                HistoryErrorState(
                    error: error,
                ),
            )
            self.messager.showUnknownError(
                l10n: self.l10n,
            )
        }
    }

    private func append(
        _ reports: [USExaminationReport],
        to sections: [HistoryDaySection],
        offset: Int,
    ) {
        var ids = Set(
            sections.flatMap {
                $0.reports.map(
                    \.id,
                )
            },
        )
        let uniqueReports = reports.filter {
            ids.insert(
                $0.id,
            ).inserted
        }
        let updated = sectionBuilder.appending(
            uniqueReports,
            to: sections,
        )
        guard !updated.isEmpty else {
            emit(
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
