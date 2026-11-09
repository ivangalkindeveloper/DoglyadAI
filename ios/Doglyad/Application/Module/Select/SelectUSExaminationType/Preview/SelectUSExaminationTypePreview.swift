#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectUSExaminationTypeContentState FirstUse",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeContentState(),
            isRecentSectionVisible: false,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectUSExaminationTypeContentState FirstUse ScrollEnd",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeContentState(),
            isRecentSectionVisible: false,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 SelectUSExaminationTypeContentState MaximumRecentTypes",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeContentState(),
            isRecentSectionVisible: true,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 SelectUSExaminationTypeContentState MaximumRecentTypes ScrollEnd",
    ) {
        SelectUSExaminationTypePreviewView(
            state: SelectUSExaminationTypeContentState(),
            isRecentSectionVisible: true,
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
