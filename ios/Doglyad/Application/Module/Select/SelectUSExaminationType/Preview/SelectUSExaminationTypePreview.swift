#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SelectUSExaminationTypeContentState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeContentState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SelectUSExaminationTypeFailedState",
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
        "SelectUSExaminationTypeLoadingState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "SelectUSExaminationTypeSelectingState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeSelectingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
