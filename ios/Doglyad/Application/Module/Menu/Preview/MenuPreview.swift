#if DEBUG
    import SwiftUI

    #Preview(
        "01 MenuContentState HistoryCountAvailable",
    ) {
        MenuPreviewView(
            state: MenuContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 MenuContentState HistoryCountAvailable ScrollEnd",
    ) {
        MenuPreviewView(
            state: MenuContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 MenuContentState HistoryCountUnavailable",
    ) {
        MenuPreviewView(
            state: MenuContentState(),
            reportsCount: nil,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 MenuContentState HistoryCountUnavailable ScrollEnd",
    ) {
        MenuPreviewView(
            state: MenuContentState(),
            reportsCount: nil,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 MenuContentState NoCompletedReports",
    ) {
        MenuPreviewView(
            state: MenuContentState(),
            reportsCount: 0,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 MenuContentState NoCompletedReports ScrollEnd",
    ) {
        MenuPreviewView(
            state: MenuContentState(),
            reportsCount: 0,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
