#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectUSExaminationTypeLoadingState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeLoadingState(),
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
        "04 SelectUSExaminationTypeSelectingState",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeSelectingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
