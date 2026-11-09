#if DEBUG
    import SwiftUI

    #Preview(
        "01 SettingsContentState HistoryCountAvailable",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SettingsContentState HistoryCountAvailable ScrollEnd",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 SettingsContentState HistoryCountUnavailable",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
            reportsCount: nil,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SettingsContentState HistoryCountUnavailable ScrollEnd",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
            reportsCount: nil,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 SettingsContentState NoCompletedReports",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
            reportsCount: 0,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 SettingsContentState NoCompletedReports ScrollEnd",
    ) {
        SettingsPreviewView(
            state: SettingsContentState(),
            reportsCount: 0,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
