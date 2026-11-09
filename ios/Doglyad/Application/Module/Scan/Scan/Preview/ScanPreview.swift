#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 ScanInitialState BeforeDraftRestoration",
    ) {
        ScanPreviewView(
            state: ScanInitialState(),
            isDraftPresent: false,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 ScanInitialState BeforeDraftRestoration ScrollEnd",
    ) {
        ScanPreviewView(
            state: ScanInitialState(),
            isDraftPresent: false,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 ScanInitializationErrorState DraftReadFailed",
    ) {
        ScanPreviewView(
            state: ScanInitializationErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 ScanInitializationErrorState DraftReadFailed ScrollEnd",
    ) {
        ScanPreviewView(
            state: ScanInitializationErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 ScanInitialState RestoredDraft",
    ) {
        ScanPreviewView(
            state: ScanInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 ScanInitialState RestoredDraft ScrollEnd",
    ) {
        ScanPreviewView(
            state: ScanInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "07 ScanGenerationLoadingState GeneratingReport",
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
        "08 ScanGenerationLoadingState GeneratingReport ScrollEnd",
    ) {
        ScanPreviewView(
            state: ScanGenerationLoadingState(
                snapshot: ModulePreviewFactory.draft,
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "09 ScanErrorState GenerationFailed",
    ) {
        ScanPreviewView(
            state: ScanErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "10 ScanErrorState GenerationFailed ScrollEnd",
    ) {
        ScanPreviewView(
            state: ScanErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "11 ScanMediaButtonView AddPhotos",
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
