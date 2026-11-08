#if DEBUG
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 Загрузка истории",
    ) {
        HistoryPreviewView(
            scenario: .loading,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 Ошибка загрузки истории",
    ) {
        HistoryPreviewView(
            scenario: .failed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 Пустая история",
    ) {
        HistoryPreviewView(
            scenario: .empty,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 Одно исследование",
    ) {
        HistoryPreviewView(
            scenario: .singleReport,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 История · группы дат и разные протоколы",
    ) {
        HistoryPreviewView(
            scenario: .groupedReports,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 Загрузка следующей страницы",
    ) {
        HistoryPreviewView(
            scenario: .loadingNextPage,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 Ошибка следующей страницы",
    ) {
        HistoryPreviewView(
            scenario: .nextPageFailed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 Карточка исследования",
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
