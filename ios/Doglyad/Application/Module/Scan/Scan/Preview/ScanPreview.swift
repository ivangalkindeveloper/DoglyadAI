#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ScanInitializingState",
    ) {
        ScanPreviewView(
            state: ScanInitializingState(),
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
        "03 ScanDefaultState",
    ) {
        ScanPreviewView(
            state: ScanDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ScanGeneratingState",
    ) {
        ScanPreviewView(
            state: ScanGeneratingState(
                snapshot: ModulePreviewFactory.draft,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 ScanLoadingState",
    ) {
        ScanPreviewView(
            state: ScanLoadingState(
                report: ModulePreviewFactory.report,
                snapshot: ModulePreviewFactory.draft,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ScanClearingState",
    ) {
        ScanPreviewView(
            state: ScanClearingState(
                previousState: ScanDefaultState(),
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
