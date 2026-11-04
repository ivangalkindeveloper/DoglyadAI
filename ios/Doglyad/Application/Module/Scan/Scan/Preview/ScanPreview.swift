#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "ScanClearingState",
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
        "ScanDefaultState",
    ) {
        ScanPreviewView(
            state: ScanDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanFailedState",
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
        "ScanGeneratingState",
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
        "ScanInitializationFailedState",
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
        "ScanInitializingState",
    ) {
        ScanPreviewView(
            state: ScanInitializingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "ScanLoadingState",
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

    #Preview {
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
