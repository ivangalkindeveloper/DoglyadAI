#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ScanInitializationLoadingState",
    ) {
        ScanPreviewView(
            state: ScanInitializationLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ScanInitializationFailedState",
    ) {
        ScanPreviewView(
            state: ScanInitializationFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 ScanInitialState",
    ) {
        ScanPreviewView(
            state: ScanInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ScanGenerationLoadingState",
    ) {
        ScanPreviewView(
            state: ScanGenerationLoadingState(
                snapshot: ModulePreviewFactory.draft,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 ScanReportSaveLoadingState",
    ) {
        ScanPreviewView(
            state: ScanReportSaveLoadingState(
                report: ModulePreviewFactory.report,
                snapshot: ModulePreviewFactory.draft,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ScanClearLoadingState",
    ) {
        ScanPreviewView(
            state: ScanClearLoadingState(
                previousState: ScanInitialState(),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 ScanFailedState",
    ) {
        ScanPreviewView(
            state: ScanFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 Кнопка добавления снимков",
    ) {
        VStack {
            ScanMediaButtonView(
                action: {},
            )

            ScanMediaButtonView(
                isCompact: true,
                action: {},
            )
        }
        .padding()
        .dThemeWrapper()
        .localization(
            DependencyContainer.previewable.l10n,
        )
    }
#endif
