#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectUSExaminationTypeRecentTypesLoadingState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeRecentTypesLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectUSExaminationTypeFailedState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeFailedState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 SelectUSExaminationTypeContentState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SelectUSExaminationTypeSelectionLoadingState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeSelectionLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
