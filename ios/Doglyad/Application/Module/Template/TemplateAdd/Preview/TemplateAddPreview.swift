#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 TemplateAddInitialState EditableForm",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 TemplateAddInitialState EditableForm ScrollEnd",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddInitialState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 TemplateAddErrorState TemplateSaveFailed",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 TemplateAddErrorState TemplateSaveFailed ScrollEnd",
    ) {
        TemplateAddPreviewView(
            state: TemplateAddErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
