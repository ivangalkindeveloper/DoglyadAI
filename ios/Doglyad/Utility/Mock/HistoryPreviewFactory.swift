#if DEBUG
    import Combine
    import DoglyadUI
    import Foundation
    import Router

    @MainActor
    enum HistoryPreviewFactory {
        enum Scenario: Hashable {
            case empty, failed, singleReport, groupedReports, nextPageFailed
        }

        static func makeContainer() -> DependencyContainer {
            DependencyContainer.makePreviewable(
                l10n: L10NPreviewFactory.make(),
                usExaminationTypesById: [
                    "thyroidGland": USExaminationType(
                        id: "thyroidGland",
                        title: "Щитовидная железа",
                        contextualStrings: [],
                    ),
                ],
            )
        }

        static func makeViewModel(
            scenario: Scenario,
            container: DependencyContainer,
            router: DRouter,
        ) -> HistoryViewModel {
            let model = HistoryViewModel(
                messager: DMessager(),
                container: container,
                router: router,
                getSubscriptionStatus: {
                    nil
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                currentReport: {
                    $0
                },
                observeReports: { _ in
                    AnyCancellable {}
                },
            )
            let state: any HistoryStateProtocol
            let reports: [USExaminationReport]
            let nextOffset: Int?
            switch scenario {
            case .empty:
                state = HistoryEmptyState()
                reports = []
                nextOffset = nil
            case .failed:
                state = HistoryErrorState(
                    error: CocoaError(
                        .fileReadCorruptFile,
                    ),
                )
                reports = []
                nextOffset = nil
            case .singleReport:
                state = HistoryContentState()
                reports = [USExaminationReportPreviewFactory.makeReport()]
                nextOffset = nil
            case .groupedReports:
                state = HistoryContentState()
                reports = makeReports()
                nextOffset = nil
            case .nextPageFailed:
                state = HistoryErrorState(
                    error: CocoaError(
                        .fileReadCorruptFile,
                    ),
                )
                reports = [USExaminationReportPreviewFactory.makeReport()]
                nextOffset = model.pageSize
            }
            model.configurePreview(
                state: state,
                reports: reports,
                nextOffset: nextOffset,
            )
            return model
        }

        private static func makeReports() -> [USExaminationReport] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(
                for: Date(),
            )
            let statuses: [USReportGenerationStatus] = [.completed, .generating, .interrupted, .failed, .cancelled]
            return [0, 0, -1, -7, -370].enumerated().map { index, day in
                let date = calendar.date(
                    byAdding: .day,
                    value: day,
                    to: today,
                )!
                return USExaminationReportPreviewFactory.makeReport(
                    date: date,
                    patientName: index == 1 ? "Тестовый пациент с длинными фамилией, именем и отчеством" : "Тестовый пациент №\(index + 1)",
                    isPhotosIncluded: index.isMultiple(
                        of: 2,
                    ),
                    modelReport: USExaminationModelReport(
                        date: date,
                        modelId: "google/medgemma-4b-it",
                        description: USExaminationReportPreviewFactory.description,
                        conclusion: "",
                        recommendations: nil,
                        generation: USReportGeneration(
                            status: statuses[
                                index,
                            ],
                        ),
                    ),
                )
            }
        }
    }
#endif
