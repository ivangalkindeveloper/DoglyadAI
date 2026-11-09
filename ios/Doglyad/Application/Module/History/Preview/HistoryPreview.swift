#if DEBUG
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 HistoryErrorState ReportsReadFailed",
    ) {
        HistoryPreviewView(
            scenario: .failed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 HistoryEmptyState NoReports",
    ) {
        HistoryPreviewView(
            scenario: .empty,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 HistoryEmptyState NoReports ScrollEnd",
    ) {
        HistoryPreviewView(
            scenario: .empty,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "04 HistoryContentState SingleReport",
    ) {
        HistoryPreviewView(
            scenario: .singleReport,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 HistoryContentState SingleReport ScrollEnd",
    ) {
        HistoryPreviewView(
            scenario: .singleReport,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "06 HistoryContentState GroupedReports",
    ) {
        HistoryPreviewView(
            scenario: .groupedReports,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 HistoryContentState GroupedReports ScrollEnd",
    ) {
        HistoryPreviewView(
            scenario: .groupedReports,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "08 HistoryErrorState NextPageReadFailed",
    ) {
        HistoryPreviewView(
            scenario: .nextPageFailed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "09 HistoryErrorState NextPageReadFailed ScrollEnd",
    ) {
        HistoryPreviewView(
            scenario: .nextPageFailed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "10 HistoryCardView ReportCard",
    ) {
        HistoryCardView(
            report: ModulePreviewFactory.report,
            onTap: {},
        )
        .padding()
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
